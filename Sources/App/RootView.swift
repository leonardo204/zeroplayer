import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case recommend, discover, presets, stats, settings
    }

    @Environment(AudioPlayerService.self) private var player
    @State private var selection: Tab = RootView.initialTab

    /// 시뮬레이터에서 특정 탭을 바로 열어 확인하려고 둔 통로다.
    /// `-ZPStartTab discover` 로 켠다. 릴리스 빌드에서는 항상 추천 탭이다.
    private static var initialTab: Tab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "ZPStartTab") {
        case "discover": return .discover
        case "presets": return .presets
        case "stats": return .stats
        case "settings": return .settings
        default: return .recommend
        }
        #else
        return .recommend
        #endif
    }
    /// `-ZPShowPlayer 1` 로 재생 화면을 바로 띄운다. 릴리스 빌드에서는 항상 닫혀 있다.
    @State private var isPlayerPresented = {
        #if DEBUG
        UserDefaults.standard.string(forKey: "ZPShowPlayer") == "1"
        #else
        false
        #endif
    }()

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
