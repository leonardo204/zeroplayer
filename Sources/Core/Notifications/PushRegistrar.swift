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

    /// AlarmKit 알람 권한. iOS 26 이상에서만 뜻이 있다.
    private(set) var alarmKitPermission: Permission = .notAsked

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

        // AlarmKit 으로 가는 기기는 서버 푸시를 받지 않는다. 시스템 알람과 푸시가
        // 같은 시각에 함께 오면 두 번 깨우는 셈이다(`AlarmDelivery`).
        guard !AlarmDelivery.usesAlarmKit else {
            await dropTokenForAlarmKit()
            return
        }
        if permission == .granted { registerWithAPNs() }
    }

    /// 예전에 올려 둔 APNs 토큰을 서버에서 지운다. 성공하면 다시 하지 않는다.
    /// 서버 푸시 토큰을 이미 지웠는지. 앱을 열 때마다 지우자고 부르지 않으려고 남긴다.
    ///
    /// 되돌릴 수 있어야 한다. 알람 권한을 껐다가 다시 켜면 그 사이에 토큰이 다시
    /// 올라가는데, 이 표시가 남아 있으면 두 번째로 켤 때 토큰을 지우지 않아
    /// 시스템 알람과 서버 푸시가 함께 울린다. 그래서 토큰을 올릴 때 지운다.
    private static let droppedKey = "zp.push.droppedForAlarmKit"

    private func dropTokenForAlarmKit() async {
        guard !UserDefaults.standard.bool(forKey: Self.droppedKey) else { return }
        do {
            try await client.deletePushToken()
            UserDefaults.standard.set(true, forKey: Self.droppedKey)
            hasToken = false
            log.info("AlarmKit 를 쓰므로 서버 푸시 토큰을 지웠다")
        } catch {
            // 다음에 앱을 열 때 다시 해 본다.
            log.info("푸시 토큰을 지우지 못했다: \(String(describing: error), privacy: .private)")
        }
    }

    // MARK: - 화면이 보는 알람 권한

    /// 알람이 울릴 준비가 됐는지. 어느 길로 가는지에 따라 보는 값이 다르다.
    var isAlarmReady: Bool {
        AlarmDelivery.isAlarmKitAvailable ? alarmKitPermission == .granted : permission == .granted
    }

    /// 화면에 띄울 권한 상태. AlarmKit 기기면 알람 권한, 그 밖에는 알림 권한이다.
    var alarmPermission: Permission {
        AlarmDelivery.isAlarmKitAvailable ? alarmKitPermission : permission
    }

    /// 사용자가 '알람 허용하기' 를 눌렀다.
    @discardableResult
    func requestAlarmPermission() async -> Bool {
        guard AlarmDelivery.isAlarmKitAvailable else { return await requestPermission() }
        let granted = await AlarmDelivery.requestAlarmKitPermission()
        refreshAlarmKitPermission()
        // 허락받은 그 자리에서 토큰을 지운다. 다음에 앱을 열 때까지 기다리면
        // 그 사이에 걸린 첫 알람이 시스템 알람과 서버 푸시로 두 번 울린다.
        if granted { await dropTokenForAlarmKit() }
        return granted
    }

    private func refreshAlarmKitPermission() {
        guard AlarmDelivery.isAlarmKitAvailable else { return }
        if AlarmDelivery.usesAlarmKit {
            alarmKitPermission = .granted
        } else if AlarmDelivery.needsAlarmKitPermission {
            alarmKitPermission = .notAsked
        } else {
            alarmKitPermission = .denied
        }
    }

    func refreshPermission() async {
        refreshAlarmKitPermission()
        #if DEBUG
        // 스크린샷 모드에서는 실제 상태로 덮어쓰지 않는다.
        if UserDefaults.standard.string(forKey: "ZPFakePushGranted") == "1" {
            alarmKitPermission = .granted
            return
        }
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
        // 푸시 길로 돌아왔다. 다시 AlarmKit 으로 갈 때 토큰을 또 지워야 하므로 표시를 턴다.
        UserDefaults.standard.set(false, forKey: Self.droppedKey)
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
