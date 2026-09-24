import AVFoundation
import Foundation

/// `AVAudioSession` 을 만지는 유일한 곳이다.
///
/// 카테고리 설정과 인터럽트·출력 경로 변경을 여기서 받아 `AudioPlayerService` 에 넘긴다.
/// `NotificationCenter` 를 쓰는 이유는 시스템이 그 방법으로만 알려주기 때문이다.
/// 화면끼리 통신하는 용도로는 쓰지 않는다.
@MainActor
final class AudioSessionManager {
    enum Interruption: Sendable {
        /// 전화가 오거나 다른 앱이 오디오를 가져갔다.
        case began
        /// 인터럽트가 끝났다. `shouldResume` 이면 우리가 다시 재생해도 된다.
        case ended(shouldResume: Bool)
    }

    var onInterruption: ((Interruption) -> Void)?
    /// 이어폰이 빠지는 등 듣던 출력 장치가 사라졌다. 애플 지침대로 이때는 멈춘다.
    var onOutputDeviceLost: (() -> Void)?

    private var isActive = false
    /// 카테고리는 한 번만 잡는다.
    private var didSetCategory = false
    /// 앞서 띄운 세션 작업. 다음 작업은 이것이 끝난 뒤에 한다.
    ///
    /// `deactivate()` 는 호출자를 기다리게 하지 않으려고 뒤에서 도는데, 그대로 두면
    /// 방금 켠 세션을 뒤늦게 끄는 일이 생긴다(프리셋 자동 선택이 죽은 방송을 만나
    /// 다음 후보로 넘어갈 때 실제로 그 순서가 된다). 그래서 부른 순서를 여기서 지킨다.
    private var pending: Task<Void, Never>?

    /// 이 객체는 앱이 사는 동안 그대로 있어서 관찰자를 따로 해제하지 않는다.
    init() {
        let center = NotificationCenter.default

        center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let payload = Self.parseInterruption(note)
            MainActor.assumeIsolated {
                guard let self, let payload else { return }
                self.onInterruption?(payload)
            }
        }

        center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let lost = Self.isOldDeviceUnavailable(note)
            MainActor.assumeIsolated {
                guard let self, lost else { return }
                self.onOutputDeviceLost?()
            }
        }
    }

    /// 재생을 시작하기 직전에 부른다.
    ///
    /// `setCategory`·`setActive` 는 메인 스레드에서 부르면 AVFoundation 이
    /// "UI unresponsiveness" 경고를 남긴다. 실제로 수십 밀리초를 잡아먹는 호출이라
    /// 방송을 누른 순간 화면이 멈칫한다. 그래서 메인 스레드 밖에서 부르고 결과만 기다린다.
    func activate() async throws {
        await pending?.value
        pending = nil

        let needsCategory = !didSetCategory
        try await Self.offMainThread {
            let session = AVAudioSession.sharedInstance()
            if needsCategory {
                try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            }
            try session.setActive(true)
        }
        didSetCategory = true
        isActive = true
    }

    /// 완전히 멈출 때만 부른다. 일시정지에서는 세션을 내리지 않는다.
    /// 세션을 내려야 다른 앱이 오디오를 돌려받는다.
    ///
    /// 세션을 내리는 것은 아무도 기다릴 필요가 없어서 뒤에서 돈다. 다만 앞선 작업과
    /// 순서가 뒤바뀌지 않게 `pending` 으로 이어 붙인다.
    func deactivate() {
        guard isActive else { return }
        isActive = false
        let previous = pending
        pending = Task { [weak self] in
            await previous?.value
            guard self != nil else { return }
            try? await Self.offMainThread {
                try AVAudioSession.sharedInstance()
                    .setActive(false, options: [.notifyOthersOnDeactivation])
            }
        }
    }

    /// 메인 스레드 밖에서 한 번 실행하고 끝날 때까지 기다린다.
    /// `AVAudioSession` 은 어느 스레드에서 불러도 되는 객체다.
    nonisolated private static func offMainThread(
        _ body: @escaping @Sendable () throws -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated, operation: body).value
    }

    nonisolated private static func parseInterruption(_ note: Notification) -> Interruption? {
        guard
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return nil }

        switch type {
        case .began:
            return .began
        case .ended:
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            return .ended(shouldResume: options.contains(.shouldResume))
        @unknown default:
            return nil
        }
    }

    nonisolated private static func isOldDeviceUnavailable(_ note: Notification) -> Bool {
        guard
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
        else { return false }
        return reason == .oldDeviceUnavailable
    }
}
