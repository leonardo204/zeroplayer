import Foundation
import Observation
import UIKit
import UserNotifications
import os

/// 알림 권한과 APNs 토큰을 맡는다.
///
/// 푸시가 도착해도 앱이 저절로 소리를 내지는 못한다(`docs/01-features.md` 5.1).
/// 사용자가 알림을 탭하거나 '재생'을 눌러야 앱이 열리고 재생이 시작된다.
/// 그래서 이 객체가 하는 일은 셋뿐이다 — 권한 묻기, 토큰을 서버에 넘기기,
/// 도착한 알림에서 무엇을 틀지 꺼내 넘기기.
@MainActor
@Observable
final class PushRegistrar: NSObject {
    enum Permission: Equatable {
        case notAsked
        case granted
        case denied

        var text: String {
            switch self {
            case .notAsked: return String(localized: "아직 묻지 않았습니다")
            case .granted: return String(localized: "허용됨")
            case .denied: return String(localized: "꺼져 있습니다")
            }
        }
    }

    private(set) var permission: Permission = {
        #if DEBUG
        // 스토어 스크린샷에서 '알림이 꺼져 있습니다' 카드를 띄우지 않으려고 둔다.
        // `-ZPFakePushGranted 1` 로 켠다. 릴리스 빌드에는 들어가지 않는다.
        if UserDefaults.standard.string(forKey: "ZPFakePushGranted") == "1" { return .granted }
        #endif
        return .notAsked
    }()
    /// APNs 에 등록됐는지. 시뮬레이터는 토큰을 받아도 실제 발송이 닿지 않는다.
    private(set) var hasToken = false
    private(set) var lastError: String?

    /// 알림을 눌러 들어왔을 때 무엇을 틀지. 화면이 이걸 보고 재생한다.
    var pendingPlay: AlarmPushInfo?

    @ObservationIgnored private let client: ProxyClienting
    @ObservationIgnored private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "push")

    /// 알림 분류와 액션. 잠금화면에서 바로 재생할 수 있게 단추를 붙인다.
    static let categoryID = "ZP_ALARM"
    static let playActionID = "ZP_PLAY"
    static let snoozeActionID = "ZP_SNOOZE"

    init(client: ProxyClienting = ProxyClient()) {
        self.client = client
        super.init()
    }

    /// 앱이 뜰 때 한 번 부른다. 권한을 새로 묻지는 않고 지금 상태만 읽는다.
    func start() async {
        registerCategories()
        UNUserNotificationCenter.current().delegate = self
        await refreshPermission()
        if permission == .granted { registerWithAPNs() }
    }

    func refreshPermission() async {
        #if DEBUG
        // 스크린샷 모드에서는 실제 상태로 덮어쓰지 않는다.
        if UserDefaults.standard.string(forKey: "ZPFakePushGranted") == "1" { return }
        #endif
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: permission = .granted
        case .denied: permission = .denied
        case .notDetermined: permission = .notAsked
        @unknown default: permission = .notAsked
        }
    }

    /// 사용자가 알람을 처음 켤 때 부른다.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            permission = granted ? .granted : .denied
            if granted { registerWithAPNs() }
            return granted
        } catch {
            log.error("알림 권한을 묻지 못했다: \(String(describing: error), privacy: .private)")
            lastError = String(localized: "알림 권한을 묻지 못했습니다.")
            return false
        }
    }

    private func registerCategories() {
        let play = UNNotificationAction(
            identifier: Self.playActionID, title: String(localized: "재생"), options: [.foreground])
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionID, title: String(localized: "5분 뒤 다시"), options: [])
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [play, snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func registerWithAPNs() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - 토큰

    /// `AppDelegate` 가 APNs 토큰을 받으면 넘겨준다.
    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        hasToken = true
        lastError = nil
        log.info("APNs 토큰을 받았다 (\(hex.count)자)")

        let client = self.client
        // 개발 빌드는 sandbox 로 보내야 도착한다. 릴리스는 prod 다.
        let sandbox = Self.isSandboxBuild
        Task.detached(priority: .utility) {
            do {
                try await client.registerPushToken(hex, sandbox: sandbox)
            } catch {
                await MainActor.run { self.lastError = String(localized: "토큰을 서버에 넘기지 못했습니다.") }
            }
        }
    }

    func didFailToRegister(_ error: Error) {
        hasToken = false
        log.error("APNs 등록 실패: \(String(describing: error), privacy: .public)")
        lastError = String(localized: "APNs 에 등록하지 못했습니다. 실기기에서 다시 확인하세요.")
    }

    /// 개발 빌드인지. APNs 는 개발·배포 환경이 갈려 있어 서버가 어디로 보낼지 알아야 한다.
    static var isSandboxBuild: Bool {
        #if DEBUG
        return true
        #else
        // TestFlight 도 개발용 인증서가 아니라 배포용이라 prod 다. App Store 와 같다.
        return false
        #endif
    }
}

// MARK: - 알림이 도착하거나 눌렸을 때

extension PushRegistrar: UNUserNotificationCenterDelegate {
    /// 앱을 열어 둔 채 알람 시각이 되면 이 쪽으로 온다. 배너와 소리를 그대로 낸다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        let info = AlarmPushInfo(userInfo: userInfo)

        await MainActor.run {
            switch action {
            case Self.snoozeActionID:
                LocalAlarmScheduler.scheduleSnooze(after: 5 * 60, userInfo: userInfo)
            default:
                // 탭이든 '재생' 단추든 같다. 앱이 열리고 그 소스를 튼다.
                self.pendingPlay = info
            }
            // 푸시가 도착했으니 같은 알람의 로컬 백업은 울릴 필요가 없다.
            if let alarmID = info?.alarmID {
                LocalAlarmScheduler.cancelDelivered(serverAlarmID: alarmID)
            }
        }
    }
}
