import SwiftData
import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case recommend, discover, presets, stats, settings
    }

    @Environment(AudioPlayerService.self) private var player
    @Environment(PushRegistrar.self) private var push
    @Environment(AdConsent.self) private var adConsent
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Tab = RootView.initialTab
    /// 알람으로 열렸을 때 화면에 띄우는 문구. 무엇을 트는지 알려 준다.
    @State private var alarmBanner: String?
    /// 밝게 볼지 어둡게 볼지. 설정에서 바꾸면 그 자리에서 화면이 바뀐다.
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.system.rawValue

    /// 시뮬레이터에서 특정 탭을 바로 열어 확인하려고 둔 통로다.
    /// `-ZPStartTab discover` 로 켠다. 릴리스 빌드에서는 항상 추천 탭이다.
    private static var initialTab: Tab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "ZPStartTab") {
        case "discover": return .discover
        case "presets": return .presets
        case "stats": return .stats
        case "settings": return .settings
        case "alarm": return .settings
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
                .withMiniPlayer { isPlayerPresented = true }
                .tabItem { Label("추천", systemImage: "sparkles") }
                .tag(Tab.recommend)

            DiscoverView()
                .withMiniPlayer { isPlayerPresented = true }
                .tabItem { Label("탐색", systemImage: "magnifyingglass") }
                .tag(Tab.discover)

            PresetsView()
                .withMiniPlayer { isPlayerPresented = true }
                .tabItem { Label("프리셋", systemImage: "square.grid.2x2") }
                .tag(Tab.presets)

            StatsView()
                .withMiniPlayer { isPlayerPresented = true }
                .tabItem { Label("기록", systemImage: "chart.bar") }
                .tag(Tab.stats)

            SettingsView()
                .withMiniPlayer { isPlayerPresented = true }
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        .sheet(isPresented: $isPlayerPresented) {
            PlayerView()
        }
        // 알림을 눌러 들어오면 여기서 받아 튼다.
        .onChange(of: push.pendingPlay?.alarmID) { _, _ in
            guard let info = push.pendingPlay else { return }
            push.pendingPlay = nil
            Task { await startAlarm(info) }
        }
        .overlay(alignment: .top) {
            if let alarmBanner {
                Label(alarmBanner, systemImage: "alarm.fill")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.bar, in: Capsule())
                    .shadow(radius: 6, y: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: alarmBanner)
    }

    /// 알람으로 깨어났다. 서버가 고른 것이 있으면 그대로 틀고, 없으면 지금 고른다.
    ///
    /// 알람 직후 화면에는 광고를 붙이지 않는다(`docs/05-ads-policy.md`).
    private func startAlarm(_ info: AlarmPushInfo) async {
        // 기상 직후 화면에는 광고를 붙이지 않는다(`docs/05-ads-policy.md` 5번).
        adConsent.enterAlarmQuietPeriod()

        let origin = PlaybackOrigin(
            presetName: String(localized: "알람"),
            fromRecommendation: info.item == nil,
            situation: info.situation
        )

        if let item = info.item {
            alarmBanner = String(localized: "알람 · \(item.title)")
            await player.play(item, origin: origin)
        } else if let situation = info.situation {
            // 로컬 백업 알림이다. 무엇을 틀지 기기가 지금 고른다.
            alarmBanner = String(localized: "알람 · 틀 방송을 고르는 중입니다")
            let launcher = PresetLauncher(player: player, fallback: {
                FavoriteStore(context: modelContext).all().map(\.playable)
            })
            if let played = try? await launcher.startSituation(situation, presetName: String(localized: "알람")) {
                alarmBanner = String(localized: "알람 · \(played.title)")
            } else {
                alarmBanner = String(localized: "알람 · 틀 방송을 찾지 못했습니다")
            }
        }

        try? await Task.sleep(for: .seconds(4))
        alarmBanner = nil
    }
}

/// 미니 플레이어를 탭 내용 아래에 끼운다.
///
/// TabView 자체에 `safeAreaInset` 을 걸면 미니 플레이어가 탭바 자리에 들어앉아
/// 재생 중에는 다른 탭으로 갈 수 없다. 탭 하나하나의 내용에 걸어야
/// 탭바는 그대로 남고 미니 플레이어가 그 위에 쌓인다.
private extension View {
    func withMiniPlayer(onTap: @escaping () -> Void) -> some View {
        modifier(MiniPlayerInset(onTap: onTap))
    }
}

private struct MiniPlayerInset: ViewModifier {
    @Environment(AudioPlayerService.self) private var player
    let onTap: () -> Void

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if player.current != nil {
                MiniPlayerView(onTap: onTap)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AudioPlayerService())
}
