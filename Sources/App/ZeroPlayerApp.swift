import SwiftData
import SwiftUI
import UIKit

/// APNs 토큰은 `UIApplicationDelegate` 로만 온다. SwiftUI 앱에도 대리자를 붙일 수 있다.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// 앱이 뜬 뒤 `ZeroPlayerApp` 이 자기 것을 꽂아 준다.
    static weak var push: PushRegistrar?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        MainActor.assumeIsolated { Self.push?.didRegister(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        MainActor.assumeIsolated { Self.push?.didFailToRegister(error) }
    }
}

@main
struct ZeroPlayerApp: App {
    private let container: ModelContainer
    private let listeningStore: ListeningStore
    @State private var player: AudioPlayerService
    /// 기기 안 모델. 쓸 수 없는 기기에서는 가용성만 알려 주고 아무 일도 하지 않는다.
    @State private var reasoner = OnDeviceReasoner()
    @State private var push = PushRegistrar()
    /// 히든 해제 상태. 토큰은 키체인에 있고 해제 전에는 화면 어디에도 안 나온다.
    @State private var hiddenAccess: HiddenAccess
    /// 광고 동의와 추적 허가. 이 값이 서지 않으면 배너를 한 장도 요청하지 않는다.
    @State private var adConsent = AdConsent()
    /// 1.7 에서 올라온 사용자에게 유튜브 기능이 없어진 이유를 한 번 보여 준다.
    @State private var showYouTubeNotice = false

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let container = Self.makeContainer()
        let store = ListeningStore(context: container.mainContext)
        let hidden = HiddenAccess()
        let player = AudioPlayerService()
        player.attach(recorder: store)
        player.attach(positions: PositionStore(context: container.mainContext))
        player.attach(hidden: hidden)

        self.container = container
        self.listeningStore = store
        _player = State(initialValue: player)
        _hiddenAccess = State(initialValue: hidden)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .sheet(isPresented: $showYouTubeNotice) { YouTubeRemovedView() }
                .environment(player)
                .environment(reasoner)
                .environment(push)
                .environment(hiddenAccess)
                .environment(adConsent)
                .task { await migrateLegacyIfNeeded() }
                .task { await adConsent.start() }
                .task { await startNotifications() }
                .task { await seedAlarmIfRequested() }
                .task { await alarmPushIfRequested() }
                .task { await unlockHiddenIfRequested() }
                .task { await autoPlayIfRequested() }
                .task { await autoPresetIfRequested() }
        }
        .modelContainer(container)
    }

    /// 1.7 이 Documents 에 남긴 JSON 을 한 번만 옮긴다.
    ///
    /// 광고 동의(`adConsent.start()`)보다 먼저 돌려야 한다. 마이그레이션이 히든을
    /// 열면 탐색 탭 갈래가 하나 늘어나는데, 동의창이 떠 있는 동안 화면이 바뀌면 어지럽다.
    private func migrateLegacyIfNeeded() async {
        let context = container.mainContext
        let alarms = AlarmStore(context: context)
        let result = await LegacyMigration(context: context).run(hidden: hiddenAccess, alarms: alarms)
        if result.hadYouTubePlaylists { showYouTubeNotice = true }
    }

    /// 목록 캐시·프리셋·즐겨찾기·청취 기록·이어듣기·알람이 한 저장소에 들어간다.
    private static func makeContainer() -> ModelContainer {
        let models: [any PersistentModel.Type] = [
            CachedStation.self, Preset.self, Favorite.self, ListeningSession.self,
            PlaybackPosition.self, AlarmSetting.self,
        ]
        let schema = Schema(models)
        do {
            return try ModelContainer(for: schema)
        } catch {
            // 저장소를 못 열면 이번 실행만 메모리로 돈다. 앱이 안 뜨는 쪽이 더 나쁘다.
            return try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }
    }

    /// 알림 권한과 APNs 등록, 그리고 서버에 남아 있는 알람을 맞춘다.
    private func startNotifications() async {
        AppDelegate.push = push
        await push.start()
        // 앱을 열었다는 것은 이미 일어났다는 뜻이다. 밀린 스누즈를 치운다.
        LocalAlarmScheduler.cancelSnoozes()
        await AlarmStore(context: container.mainContext).syncAll()
    }

    /// 알람을 손으로 만들지 않고 확인하려고 둔 통로다.
    /// `-ZPSeedAlarm 07:00` 으로 켠다. 릴리스 빌드에는 들어가지 않는다.
    private func seedAlarmIfRequested() async {
        #if DEBUG
        guard let raw = UserDefaults.standard.string(forKey: "ZPSeedAlarm"), raw.contains(":") else { return }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let store = AlarmStore(context: container.mainContext)
        guard store.all().isEmpty else { return }
        await store.add(AlarmSetting(
            hour: parts[0], minute: parts[1],
            weekdays: [2, 3, 4, 5, 6],
            sourceKind: .auto, situation: .wake, label: "아침"))
        #endif
    }

    /// 알림을 누른 상황을 손으로 만들지 않고 확인하려고 둔 통로다.
    /// `-ZPAlarmPush rb:<uuid>` 또는 `-ZPAlarmPush situation:wake` 로 켠다.
    /// 릴리스 빌드에는 들어가지 않는다.
    private func alarmPushIfRequested() async {
        #if DEBUG
        guard let raw = UserDefaults.standard.string(forKey: "ZPAlarmPush"), !raw.isEmpty else { return }
        var zp: [String: Any] = ["alarmID": "alm_debug"]
        if raw.hasPrefix("situation:") {
            zp["situation"] = String(raw.dropFirst("situation:".count))
        } else {
            zp["kind"] = "station"
            zp["id"] = raw
            zp["title"] = "알람이 고른 방송"
        }
        push.pendingPlay = AlarmPushInfo(userInfo: ["zp": zp])
        #endif
    }

    /// 프리셋을 손으로 누르지 않고 확인하려고 둔 통로다.
    /// `-ZPAutoPreset 취침` 으로 켠다. 릴리스 빌드에는 들어가지 않는다.
    private func autoPresetIfRequested() async {
        #if DEBUG
        guard let name = UserDefaults.standard.string(forKey: "ZPAutoPreset"), !name.isEmpty else { return }
        let context = container.mainContext
        if (try? context.fetch(FetchDescriptor<Preset>()))?.isEmpty ?? true {
            for preset in Preset.defaults() { context.insert(preset) }
            try? context.save()
        }
        let presets = (try? context.fetch(FetchDescriptor<Preset>(sortBy: [SortDescriptor(\Preset.order)]))) ?? []
        guard let preset = presets.first(where: { $0.name == name }) else { return }
        let launcher = PresetLauncher(
            player: player,
            fallback: { FavoriteStore(context: context).all().map(\.playable) },
            profiles: { ListeningStore(context: context).profiles(situation: $0) }
        )
        _ = try? await launcher.start(preset)
        #endif
    }

    /// 지상파 해제를 손으로 12번 누르지 않고 확인하려고 둔 통로다.
    /// `-ZPUnlockHidden 1` 로 켠다. 릴리스 빌드에는 들어가지 않는다.
    private func unlockHiddenIfRequested() async {
        #if DEBUG
        guard UserDefaults.standard.string(forKey: "ZPUnlockHidden") == "1" else { return }
        guard !hiddenAccess.isUnlocked else { return }
        if let result = try? await ProxyClient().unlockHidden() {
            hiddenAccess.store(token: result.token)
        }
        #endif
    }

    /// 재생 경로를 손으로 누르지 않고 확인하려고 둔 통로다.
    /// `-ZPAutoPlay rb:<uuid>` 는 방송국, `kr:<채널>` 은 지상파,
    /// `-ZPAutoEpisode it:<피드>:<에피소드>` 는 에피소드다.
    /// 릴리스 빌드에는 들어가지 않는다.
    private func autoPlayIfRequested() async {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "ZPFakeNowPlaying") == "1" {
            player.debugShowFakeItem()
            return
        }
        if let id = UserDefaults.standard.string(forKey: "ZPAutoEpisode"), !id.isEmpty {
            let feedID = id.split(separator: ":").prefix(2).joined(separator: ":")
            await player.play(PlayableItem(
                id: id,
                kind: .podcast,
                title: "확인용 에피소드",
                subtitle: feedID,
                feedID: feedID
            ))
            // 이어듣기가 저장되는지 보려고 조금 앞으로 옮겨 둔다.
            if let jump = UserDefaults.standard.string(forKey: "ZPSeekTo"), let seconds = Double(jump) {
                try? await Task.sleep(for: .seconds(4))
                player.seek(to: seconds)
            }
            return
        }
        guard let id = UserDefaults.standard.string(forKey: "ZPAutoPlay"), !id.isEmpty else { return }
        // 'kr:' 로 시작하면 지상파다. 해제 토큰이 있어야 주소를 받는다.
        let kind: SourceKind = id.hasPrefix("kr:") ? .hidden : .station
        await player.play(PlayableItem(id: id, kind: kind, title: id))
        #endif
    }
}
