import Foundation
import os

/// 알람 화면의 단추가 눌렸을 때 재생을 시작하는 통로.
///
/// AlarmKit 알람의 단추는 App Intent 를 실행한다. 그때 앱 프로세스는 살아나지만
/// 화면은 열리지 않는다(`docs/10-alarmkit.md`). 화면이 없으니 인텐트는 뷰를 거칠 수
/// 없고, 그렇다고 재생기를 새로 만들면 청취 기록도 잠금화면 표시도 따로 돈다.
/// 그래서 앱이 뜰 때 자기 재생기를 여기 꽂아 두고, 인텐트는 여기로 와서 부른다.
///
/// 인텐트가 `App.init` 보다 먼저 돌 수도 있어서 꽂히기를 잠깐 기다린다.
@MainActor
final class AlarmPlaybackBridge {
    static let shared = AlarmPlaybackBridge()

    private weak var player: (any AudioPlaying)?
    /// 자동 선택 알람이 무엇을 틀지 물을 곳.
    private var client: any ProxyClienting = ProxyClient()
    /// 기기에 쌓인 청취 기록. 후보 순서를 다시 세우는 데 쓴다.
    ///
    /// 이것이 없으면 서버 1위가 그대로 울린다. 30초 안에 넘긴 방송이 다음 아침에 또
    /// 나오던 이유가 그것이었다 — 프리셋은 재정렬을 거치는데 알람만 빠져 있었다.
    private var profiles: (Situation) -> [String: ListeningProfile] = { _ in [:] }
    private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")

    private init() {}

    /// 앱이 뜰 때 한 번 부른다.
    func attach(player: any AudioPlaying) {
        self.player = player
    }

    /// 시험에서 가짜 서버를 꽂을 자리.
    func attach(client: any ProxyClienting) {
        self.client = client
    }

    /// 청취 기록을 읽는 통로를 꽂는다. 앱이 뜰 때 한 번 부른다.
    func attach(profiles: @escaping (Situation) -> [String: ListeningProfile]) {
        self.profiles = profiles
    }

    /// 알람 단추가 눌렸다. 재생이 실제로 붙을 때까지 기다린 뒤 알려 준다.
    ///
    /// 돌려주는 값을 인텐트가 기다리는 이유는 하나다. `perform` 이 먼저 끝나면
    /// 시스템이 프로세스를 거둬 갈 수 있어서, 재생이 붙는 것까지는 보고 나와야 한다.
    @discardableResult
    func startFromAlarm(item: PlayableItem?, situation: Situation?) async -> Bool {
        guard let player = await waitForPlayer() else {
            log.error("알람 단추를 눌렀는데 재생기가 아직 없다")
            return false
        }

        // 예약할 때 골라 둔 것이 그 뒤에 '그만 듣기' 로 빠졌을 수 있다. 그때는 버리고
        // 지금 다시 고른다 — 뺀 방송으로 깨우면 뺀 의미가 없다.
        let skip = player.excludedStationIDs
        var picked: PlayableItem?
        if let item, !skip.contains(item.id) { picked = item }

        var list: [PlayableItem] = []
        if let picked {
            list = [picked]
        } else if let situation {
            list = await candidates(situation: situation)
        }

        guard let target = list.first else {
            log.error("알람이 무엇을 틀지 못 정했다")
            return false
        }

        let origin = PlaybackOrigin(
            presetName: nil, fromRecommendation: picked == nil, situation: situation)
        // 후보 줄을 재생기에 넘긴다. 잠에서 깬 사람이 '그만 듣기' 를 누르면 다음으로 넘어간다.
        if list.count > 1 { player.setQueue(list, origin: origin) }
        await player.play(target, origin: origin)
        return await waitUntilPlaying(player)
    }

    // MARK: - 기다리기

    /// `App.init` 이 재생기를 꽂을 때까지.
    private func waitForPlayer(timeout: Duration = .seconds(3)) async -> (any AudioPlaying)? {
        if let player { return player }
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
            if let player { return player }
        }
        return player
    }

    /// 첫 오디오가 붙을 때까지. 실패로 끝나면 false 다.
    private func waitUntilPlaying(
        _ player: any AudioPlaying, timeout: Duration = .seconds(20)
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            switch player.state {
            case .playing:
                return true
            case .failed:
                log.error("알람이 고른 방송을 틀지 못했다")
                return false
            case .idle, .loading, .paused:
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        log.info("알람 재생이 \(timeout) 안에 붙지 않았다")
        return false
    }

    // MARK: - 자동 선택

    /// 상황만 정해 둔 알람이 무엇을 틀지 고른다. 앞에서부터 쓸 수 있는 순서다.
    ///
    /// 프리셋(`PresetLauncher.candidates`)과 같은 세 단계를 거친다 — 서버 규칙 목록을
    /// 받고, 기기 기록으로 다시 세우고, '그만 듣기' 로 뺀 것을 걸러낸다.
    func candidates(situation: Situation) async -> [PlayableItem] {
        let query = RecommendQuery(
            situation: situation,
            country: Locale.current.region?.identifier,
            at: .now,
            limit: 20,
            // 앱이 고르는 자리라 열리는 스트림만 받는다(`CONTEXT.md` 6번).
            secureOnly: true,
            timerMinutes: 0
        )
        let set: RecommendationSetDTO
        do {
            set = try await client.recommendations(query)
        } catch {
            log.info("알람이 틀 것을 서버에 못 물었다: \(String(describing: error), privacy: .private)")
            return []
        }

        let skip = player?.excludedStationIDs ?? []
        let ranked = Personalizer().rank(set.items, profiles: profiles(situation))
        let list = ranked.map(\.item.playable).filter { !skip.contains($0.id) }
        log.info("알람 후보 \(list.count)개 (제외 \(set.items.count - list.count)건)")

        return list.map { item in
            var copy = item
            copy.subtitle = String(localized: "알람")
            return copy
        }
    }

    /// 예약할 때 미리 하나 골라 둔다. 그때 고른 것이 인텐트 인자로 들어간다.
    ///
    /// 알람 시각까지 며칠이 남아 있을 수 있어서, 그 사이에 방송이 죽거나 사용자가
    /// 그 방송을 빼면 `startFromAlarm` 이 그 자리에서 다시 고른다.
    func resolve(situation: Situation) async -> PlayableItem? {
        await candidates(situation: situation).first
    }
}
