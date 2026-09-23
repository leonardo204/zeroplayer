import SwiftUI

@main
struct ZeroPlayerApp: App {
    @State private var player = AudioPlayerService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .task { await autoPlayIfRequested() }
        }
    }

    /// 재생을 손으로 눌러보지 않고 확인하려고 둔 통로다.
    /// `-ZPAutoPlay demo.somafm.groovesalad` 로 켠다. 릴리스 빌드에는 들어가지 않는다.
    private func autoPlayIfRequested() async {
        #if DEBUG
        guard let id = UserDefaults.standard.string(forKey: "ZPAutoPlay"),
              let entry = DemoStations.all.first(where: { $0.item.id == id })
        else { return }
        await player.play(entry.item)
        #endif
    }
}
