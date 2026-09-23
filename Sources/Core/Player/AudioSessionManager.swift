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

    /// 재생을 시작하기 직전에 부른다. 이미 켜져 있으면 아무 일도 하지 않는다.
    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        if !isActive {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
        }
        try session.setActive(true)
        isActive = true
    }

    /// 완전히 멈출 때만 부른다. 일시정지에서는 세션을 내리지 않는다.
    /// 세션을 내려야 다른 앱이 오디오를 돌려받는다.
    func deactivate() {
        guard isActive else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        isActive = false
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
