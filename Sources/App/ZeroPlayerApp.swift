import SwiftData
import SwiftUI

@main
struct ZeroPlayerApp: App {
    private let container: ModelContainer
    private let listeningStore: ListeningStore
    @State private var player: AudioPlayerService
    /// 기기 안 모델. 쓸 수 없는 기기에서는 가용성만 알려 주고 아무 일도 하지 않는다.
    @State private var reasoner = OnDeviceReasoner()

    init() {
        let container = Self.makeContainer()
        let store = ListeningStore(context: container.mainContext)
        let player = AudioPlayerService()
        player.attach(recorder: store)

        self.container = container
        self.listeningStore = store
        _player = State(initialValue: player)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(reasoner)
                .task { await autoPlayIfRequested() }
                .task { await autoPresetIfRequested() }
        }
        .modelContainer(container)
    }

    /// 목록 캐시·프리셋·즐겨찾기·청취 기록이 한 저장소에 들어간다.
    /// 알람(M6)은 여기에 `AlarmSetting` 을 더한다.
    private static func makeContainer() -> ModelContainer {
        let models: [any PersistentModel.Type] = [
            CachedStation.self, Preset.self, Favorite.self, ListeningSession.self,
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

    /// 재생 경로를 손으로 누르지 않고 확인하려고 둔 통로다.
    /// `-ZPAutoPlay rb:<uuid>` 로 켠다. 릴리스 빌드에는 들어가지 않는다.
    private func autoPlayIfRequested() async {
        #if DEBUG
        guard let id = UserDefaults.standard.string(forKey: "ZPAutoPlay"), !id.isEmpty else { return }
        await player.play(PlayableItem(id: id, kind: .station, title: id))
        #endif
    }
}
