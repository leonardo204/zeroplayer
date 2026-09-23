import SwiftUI

@main
struct ZeroPlayerApp: App {
    @State private var player = AudioPlayerService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
        }
    }
}
