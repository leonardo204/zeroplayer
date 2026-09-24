import Foundation
import Observation
import os

/// 자동 종료 타이머. 앱에 타이머는 이것 하나만 둔다.
///
/// 1.7 은 타이머가 일곱 개였고 서로 무효화하는 순서가 흩어져 있었다. 여기서는
/// 반복 `Task` 하나가 남은 시간을 줄이고, 마지막 구간에서 볼륨을 내리고, 0 이 되면 끈다.
@MainActor
@Observable
final class SleepTimer {
    /// 남은 시간. 타이머가 없으면 nil 이다.
    private(set) var remaining: TimeInterval?
    private(set) var totalMinutes: Int?
    private(set) var isFading = false

    /// 페이드아웃 중 볼륨을 받는다. 0.0~1.0.
    @ObservationIgnored var onVolume: ((Float) -> Void)?
    /// 시간이 다 됐다. 재생을 끄는 쪽에서 채운다.
    @ObservationIgnored var onFinish: (() -> Void)?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var deadline: Date?
    @ObservationIgnored private var fadeSeconds: TimeInterval = 30
    @ObservationIgnored private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer",
        category: "timer"
    )

    private static let tick: Duration = .milliseconds(500)

    var isRunning: Bool { remaining != nil }

    /// 남은 시간을 '12:34' 로 적는다. 한 시간을 넘으면 '1:02:03'.
    var remainingText: String? {
        guard let remaining else { return nil }
        let total = Int(remaining.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    func start(minutes: Int, fadeOutSeconds: Int) {
        #if DEBUG
        // 45분을 기다리지 않고 페이드아웃까지 확인하려고 둔 통로다.
        // `-ZPTimerSeconds 40` 으로 켠다. 릴리스 빌드에는 들어가지 않는다.
        let override = UserDefaults.standard.integer(forKey: "ZPTimerSeconds")
        if override > 0 {
            start(seconds: TimeInterval(override), fadeOutSeconds: fadeOutSeconds)
            return
        }
        #endif
        start(seconds: TimeInterval(minutes * 60), fadeOutSeconds: fadeOutSeconds)
    }

    private func start(seconds: TimeInterval, fadeOutSeconds: Int) {
        guard seconds > 0 else { cancel(); return }
        cancelTask()

        let total = seconds
        fadeSeconds = min(TimeInterval(max(0, fadeOutSeconds)), total)
        deadline = Date().addingTimeInterval(total)
        totalMinutes = Int((total / 60).rounded())
        remaining = total
        isFading = false
        onVolume?(1)

        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tick)
                guard !Task.isCancelled else { return }
                guard let self else { return }
                if self.step() { return }
            }
        }
    }

    /// 타이머를 늘린다. 타이머가 없으면 그 길이로 새로 시작한다.
    func extend(minutes: Int) {
        guard minutes > 0 else { return }
        let left = max(0, remaining ?? 0)
        start(seconds: left + TimeInterval(minutes * 60), fadeOutSeconds: Int(fadeSeconds))
    }

    func cancel() {
        cancelTask()
        deadline = nil
        remaining = nil
        totalMinutes = nil
        if isFading { onVolume?(1) }
        isFading = false
    }

    /// 재생이 다른 이유로 끝났을 때. 볼륨만 되돌리고 조용히 정리한다.
    func reset() {
        cancelTask()
        deadline = nil
        remaining = nil
        totalMinutes = nil
        isFading = false
        onVolume?(1)
    }

    // MARK: - 안쪽

    /// 한 번 재고 끝났으면 true 를 준다.
    private func step() -> Bool {
        guard let deadline else { return true }
        let left = deadline.timeIntervalSinceNow

        guard left > 0 else {
            remaining = 0
            isFading = false
            onVolume?(1)
            cancelTask()
            self.deadline = nil
            remaining = nil
            totalMinutes = nil
            onFinish?()
            return true
        }

        remaining = left
        if fadeSeconds > 0, left <= fadeSeconds {
            if !isFading {
                isFading = true
                log.info("페이드아웃 시작 (남은 \(Int(left))초)")
            }
            onVolume?(Float(max(0, min(1, left / fadeSeconds))))
        }
        return false
    }

    private func cancelTask() {
        task?.cancel()
        task = nil
    }
}
