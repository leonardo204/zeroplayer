import Foundation
import os

/// 프리셋을 눌렀을 때 실제로 벌어지는 일. 소스를 정하고, 재생하고, 타이머를 건다.
///
/// `.auto` 는 서버 추천(`GET /recommend`)에서 후보를 받아 기기 기록으로 다시 세운 뒤
/// 맨 위에서부터 실제로 소리가 나는 것을 찾는다. 서버가 1·2단, 여기가 3단이다.
@MainActor
struct PresetLauncher {
    enum LaunchError: LocalizedError {
        case noSource
        case emptyRecommendation
        case allCandidatesFailed
        case playbackFailed
        case proxy(ProxyError)

        var errorDescription: String? {
            switch self {
            case .noSource: "이 프리셋에 방송국이 지정돼 있지 않습니다."
            case .emptyRecommendation: "지금 조건에 맞는 방송을 찾지 못했습니다."
            case .allCandidatesFailed: "고른 방송이 모두 응답하지 않습니다."
            case .playbackFailed: "이 방송이 응답하지 않습니다."
            case .proxy(let error): error.errorDescription
            }
        }
    }

    /// 자동 선택에서 몇 번까지 다음 후보로 넘어갈지.
    private static let autoAttempts = 3

    let player: AudioPlayerService
    let client: ProxyClienting
    /// 서버에 닿지 못했을 때 대신 쓸 후보. 즐겨찾기를 넣어 준다.
    let fallback: () -> [PlayableItem]
    /// 기기에 쌓인 청취 기록. 후보 순서를 다시 세우는 데 쓴다.
    let profiles: (Situation) -> [String: ListeningProfile]

    private var log: Logger { Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "preset") }

    init(
        player: AudioPlayerService,
        client: ProxyClienting = ProxyClient(),
        fallback: @escaping () -> [PlayableItem] = { [] },
        profiles: @escaping (Situation) -> [String: ListeningProfile] = { _ in [:] }
    ) {
        self.player = player
        self.client = client
        self.fallback = fallback
        self.profiles = profiles
    }

    /// 무엇을 틀었는지 돌려준다. 화면은 이 제목을 그대로 보여준다.
    @discardableResult
    func start(_ preset: Preset) async throws -> PlayableItem {
        let origin = PlaybackOrigin(
            presetName: preset.name,
            fromRecommendation: preset.sourceKind == .auto,
            situation: preset.situation
        )

        let played: PlayableItem
        switch preset.sourceKind {
        case .station:
            guard let id = preset.sourceID else { throw LaunchError.noSource }
            let item = PlayableItem(
                id: id,
                kind: .station,
                title: preset.sourceTitle ?? preset.name,
                subtitle: preset.name
            )
            await player.play(item, origin: origin)
            guard await waitUntilPlaying() else { throw LaunchError.playbackFailed }
            played = item

        case .auto:
            played = try await playFirstWorking(candidates(for: preset), origin: origin)
        }

        if preset.timerMinutes > 0 {
            player.startSleepTimer(minutes: preset.timerMinutes, fadeOutSeconds: preset.fadeOutSeconds)
        } else {
            player.cancelSleepTimer()
        }

        return played
    }

    /// 서버 규칙 추천의 후보 목록. 서버에 못 닿으면 즐겨찾기를 쓴다.
    private func candidates(for preset: Preset) async throws -> [PlayableItem] {
        let query = RecommendQuery(
            situation: preset.situation,
            country: Locale.current.region?.identifier,
            at: .now,
            limit: 20,
            // 평문 HTTP 스트림은 지금 기기에서 열리지 않는다(`CONTEXT.md` 5번).
            // 사람이 고른 것이 아니라 앱이 고르는 자리라서, 열리는 것만 받는다.
            secureOnly: true,
            // 타이머를 켠 프리셋이면 그 길이에 맞는 에피소드도 후보에 들어온다.
            timerMinutes: preset.timerMinutes
        )

        do {
            let set = try await client.recommendations(query)
            guard !set.items.isEmpty else { throw LaunchError.emptyRecommendation }
            // 3단. 서버 순서를 시작점으로 두고 내 기록으로 다시 세운다.
            let ranked = Personalizer().rank(set.items, profiles: profiles(preset.situation))
            log.info("자동 선택 후보 \(set.items.count)개 (\(set.source, privacy: .public)/\(set.daypart, privacy: .public))")
            return ranked.map(\.item.playable)
        } catch let error as ProxyError {
            let backup = fallback()
            guard !backup.isEmpty else { throw LaunchError.proxy(error) }
            log.info("서버에 닿지 못해 즐겨찾기에서 고른다")
            return backup
        }
    }

    /// 앞에서부터 실제로 소리가 나는 것을 찾는다. 죽은 스트림을 만나면 다음으로 넘어간다.
    private func playFirstWorking(
        _ items: [PlayableItem],
        origin: PlaybackOrigin
    ) async throws -> PlayableItem {
        guard !items.isEmpty else { throw LaunchError.emptyRecommendation }

        for item in items.prefix(Self.autoAttempts) {
            await player.play(item, origin: origin)
            if await waitUntilPlaying() {
                log.info("자동 선택: \(item.title, privacy: .public)")
                return item
            }
            log.info("응답하지 않아 다음 후보로 넘어간다: \(item.title, privacy: .public)")
        }
        throw LaunchError.allCandidatesFailed
    }

    /// `.loading` 을 벗어날 때까지 기다린다. 소리가 나기 시작하면 true.
    private func waitUntilPlaying() async -> Bool {
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            switch player.state {
            case .loading:
                try? await Task.sleep(for: .milliseconds(100))
            case .playing, .paused:
                return true
            case .failed, .idle:
                return false
            }
        }
        return false
    }
}
