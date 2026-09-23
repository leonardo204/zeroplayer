import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case recommend, discover, presets, stats, settings
    }

    @Environment(AudioPlayerService.self) private var player
    @State private var selection: Tab = .recommend
    @State private var isPlayerPresented = false

    var body: some View {
        TabView(selection: $selection) {
            RecommendView()
                .tabItem { Label("추천", systemImage: "sparkles") }
                .tag(Tab.recommend)

            DiscoverView()
                .tabItem { Label("탐색", systemImage: "magnifyingglass") }
                .tag(Tab.discover)

            PresetsView()
                .tabItem { Label("프리셋", systemImage: "square.grid.2x2") }
                .tag(Tab.presets)

            StatsView()
                .tabItem { Label("기록", systemImage: "chart.bar") }
                .tag(Tab.stats)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .safeAreaInset(edge: .bottom) {
            if player.current != nil {
                MiniPlayerView(onTap: { isPlayerPresented = true })
            }
        }
        .sheet(isPresented: $isPlayerPresented) {
            PlayerView()
        }
    }
}

#Preview {
    RootView()
        .environment(AudioPlayerService())
}
