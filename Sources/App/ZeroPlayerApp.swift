import SwiftData
import SwiftUI
import UIKit
import os

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

        // 알람 화면의 단추가 눌리면 화면 없이 이 재생기를 쓴다(`docs/10-alarmkit.md`).
        AlarmPlaybackBridge.shared.attach(player: player)

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
                .task { await bakeTonesIfRequested() }
                .task { seedHistoryIfRequested() }
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
    /// 스토어 스크린샷에서 기록 탭이 비어 보이지 않게 지난 청취 기록을 심는다.
    /// `-ZPSeedHistory 1` 로 켠다. 릴리스 빌드에는 들어가지 않는다.
    private func seedHistoryIfRequested() {
        #if DEBUG
        guard UserDefaults.standard.string(forKey: "ZPSeedHistory") == "1" else { return }
        let context = container.mainContext
        guard ((try? context.fetch(FetchDescriptor<ListeningSession>()))?.isEmpty ?? true) else { return }

        // 실제로 쌓였을 법한 모양으로 둔다 — 프리셋으로 켠 것과 목록에서 고른 것이 섞인다.
        let sleep = String(localized: "취침")
        let study = String(localized: "공부")
        let work = String(localized: "작업")
        let rows: [(String, String, Situation?, String?, Int, Int)] = [
            ("rb:sample.jazz24", "Jazz24", .sleep, sleep, 45, 1),
            ("rb:sample.classic", "KBS Classic FM", .study, study, 92, 1),
            ("rb:sample.spa", "0R - SPA LOUNGE", .sleep, sleep, 45, 2),
            ("rb:sample.paradise", "Radio Paradise", .work, work, 128, 2),
            ("rb:sample.jazz24", "Jazz24", .sleep, sleep, 45, 3),
            ("rb:sample.gugak", "Gugak FM", nil, nil, 26, 4),
            ("rb:sample.classic", "KBS Classic FM", .study, study, 88, 5),
            ("rb:sample.paradise", "Radio Paradise", .work, work, 74, 6),
            ("rb:sample.jazz24", "Jazz24", .sleep, sleep, 45, 7),
            ("rb:sample.spa", "0R - SPA LOUNGE", .sleep, sleep, 39, 8),
        ]
        for (id, title, situation, preset, minutes, daysAgo) in rows {
            let item = PlayableItem(id: id, kind: .station, title: title)
            let origin = PlaybackOrigin(
                presetName: preset, fromRecommendation: preset != nil, situation: situation)
            let session = ListeningSession(
                item: item,
                origin: origin,
                startedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
                duration: TimeInterval(minutes * 60))
            context.insert(session)
        }
        try? context.save()
        #endif
    }

    /// 알람음 20곡을 실제로 구워 보고 결과를 로그에 남긴다.
    /// `-ZPBakeTones 1` 로 켠다. 곡을 더했을 때 기기에서 풀리는지 확인하는 자리다.
    /// 릴리스 빌드에는 들어가지 않는다.
    private func bakeTonesIfRequested() async {
        #if DEBUG
        // 결과를 파일로도 남긴다. 케이블로 로그를 못 볼 때 이것만 꺼내 보면 된다.
        var report = ["args=\(ProcessInfo.processInfo.arguments.joined(separator: " "))"]
        func flush() {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? report.joined(separator: "\n").write(
                to: dir.appendingPathComponent("bake-report.txt"), atomically: true, encoding: .utf8)
        }
        flush()
        guard UserDefaults.standard.string(forKey: "ZPBakeTones") == "1" else { return }
        let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")
        var ok = 0
        for tone in AlarmSoundCatalog.tones {
            guard let data = AlarmSoundCatalog.wavData(tone: tone, volume: 1, fadeIn: false) else {
                log.error("굽기 실패 \(tone.id, privacy: .public)")
                continue
            }
            // 머리말에 적힌 표본율로 길이를 센다. 음원을 다시 구우면 바뀌는 값이다.
            let rate = data.withUnsafeBytes { raw -> UInt32 in
                raw.loadUnaligned(fromByteOffset: 24, as: UInt32.self).littleEndian
            }
            let seconds = Double(data.count - 44) / 2 / Double(max(1, rate))
            log.info("구움 \(tone.id, privacy: .public) \(data.count)바이트 \(rate)Hz \(String(format: "%.1f", seconds))초")
            report.append("\(tone.id) \(data.count)바이트 \(rate)Hz \(String(format: "%.1f", seconds))초")
            _ = AlarmSoundStore.ensure(tone: tone, volume: 1, fadeIn: false)
            ok += 1
        }
        log.info("알람음 \(ok)/\(AlarmSoundCatalog.tones.count) 곡을 구웠다")
        report.append("구운 곡 \(ok)/\(AlarmSoundCatalog.tones.count)")
        flush()
        #endif
    }

    private func seedAlarmIfRequested() async {
        #if DEBUG
        guard let raw = UserDefaults.standard.string(forKey: "ZPSeedAlarm"), raw.contains(":") else { return }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let store = AlarmStore(context: container.mainContext)
        guard store.all().isEmpty else { return }
        // 알람음까지 골라 둔다. `-ZPSeedTone bach-cello1` 로 키를 주고,
        // `-ZPSeedVolume 0.4` 로 음량을 준다. 알람음이 실제로 파일로 구워지는지
        // 손으로 고르지 않고 확인하려고 둔 통로다.
        let toneID = UserDefaults.standard.string(forKey: "ZPSeedTone")
        let volume = UserDefaults.standard.object(forKey: "ZPSeedVolume") as? Double
        let alarm = AlarmSetting(
            hour: parts[0], minute: parts[1],
            weekdays: [2, 3, 4, 5, 6],
            sourceKind: .auto, situation: .wake, label: String(localized: "아침"),
            soundToneID: toneID.flatMap { AlarmSoundCatalog.tone(id: $0) }?.id,
            soundVolume: volume ?? 0.8,
            soundFadeIn: UserDefaults.standard.string(forKey: "ZPSeedFade") == "1")
        await store.add(alarm)
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
        // 이름을 서버에서 받아 온다. 그냥 ID 를 제목으로 쓰면 화면이 무엇을 트는지 안 보인다.
        var item = PlayableItem(id: id, kind: kind, title: id)
        if kind == .station, let dto = try? await ProxyClient().station(id: id) {
            item = dto.playable
        }
        await player.play(item)

        // 일시정지했다가 다시 재생하는 길을 손으로 누르지 않고 확인한다.
        // `-ZPPauseResume 1` 로 켠다.
        if UserDefaults.standard.string(forKey: "ZPPauseResume") == "1" {
            try? await Task.sleep(for: .seconds(5))
            player.pause()
            try? await Task.sleep(for: .seconds(3))
            await player.resume()
        }
        #endif
    }
}
