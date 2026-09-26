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

        let target: PlayableItem?
        if let item {
            target = item
        } else if let situation {
            target = await resolve(situation: situation)
        } else {
            target = nil
        }

        guard let target else {
            log.error("알람이 무엇을 틀지 못 정했다")
            return false
        }

        let origin = PlaybackOrigin(
            presetName: nil, fromRecommendation: item == nil, situation: situation)
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

    /// 상황만 정해 둔 알람이 무엇을 틀지 서버에 묻는다.
    ///
    /// 예약할 때 미리 골라 두지만(그때 고른 것이 인텐트 인자로 들어온다),
    /// 그 사이에 방송이 죽었거나 예약 때 서버에 못 닿았으면 여기서 다시 고른다.
    func resolve(situation: Situation) async -> PlayableItem? {
        let query = RecommendQuery(
            situation: situation,
            country: Locale.current.region?.identifier,
            at: .now,
            limit: 10,
            // 앱이 고르는 자리라 열리는 스트림만 받는다(`CONTEXT.md` 6번).
            secureOnly: true,
            timerMinutes: 0
        )
        do {
            let set = try await client.recommendations(query)
            guard let first = set.items.first else { return nil }
            var item = first.playable
            item.subtitle = String(localized: "알람")
            return item
        } catch {
            log.info("알람이 틀 것을 서버에 못 물었다: \(String(describing: error), privacy: .private)")
            return nil
        }
    }
}
