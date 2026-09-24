import SwiftData
import SwiftUI

@main
struct ZeroPlayerApp: App {
    @State private var player = AudioPlayerService()

    /// 목록 캐시만 담는다. 프리셋·청취 기록은 M3 에서 이 컨테이너에 더한다.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: CachedStation.self)
        } catch {
            // 저장소를 못 열면 캐시 없이라도 앱은 떠야 한다.
            return try! ModelContainer(
                for: CachedStation.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .task { await autoPlayIfRequested() }
        }
        .modelContainer(container)
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
