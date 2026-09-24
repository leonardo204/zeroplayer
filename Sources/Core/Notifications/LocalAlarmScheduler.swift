import Foundation
import UserNotifications
import os

/// 서버 푸시가 못 올 때를 위한 로컬 백업 알림.
///
/// 서버가 죽거나 기기가 비행기 모드면 푸시가 통째로 안 온다. 그래서 같은 시각에
/// 로컬 알림을 함께 예약해 둔다(`docs/01-features.md` 5.3). 로컬 알림은 무엇이
/// 방송 중인지 모르므로 본문을 단순하게 둔다.
///
/// `UNCalendarNotificationTrigger` 는 요일을 하나만 받는다. 그래서 요일마다 식별자를
/// 따로 두고 예약한다. 1.x 도 같은 방식이었다.
enum LocalAlarmScheduler {
    private static let prefix = "zp.alarm."
    private static let snoozePrefix = "zp.snooze."
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")

    /// 로컬 알림은 예약 한도가 64개다. 알람 하나가 요일 수만큼 자리를 먹으므로
    /// 앞에서부터 이만큼만 건다. 넘는 알람은 서버 푸시로만 온다.
    static let maxScheduled = 60

    static func identifiers(for alarm: AlarmSetting) -> [String] {
        let days = alarm.weekdays
        if days.isEmpty { return ["\(prefix)\(alarm.localID.uuidString).once"] }
        return days.sorted().map { "\(prefix)\(alarm.localID.uuidString).\($0)" }
    }

    /// 알람 목록 전체를 다시 건다. 만들고 고치고 지운 뒤에 한 번 부른다.
    static func reschedule(_ alarms: [AlarmSetting]) async {
        let center = UNUserNotificationCenter.current()

        // 권한을 받기 전에 알림을 걸면 iOS 가 그 자리에서 권한 창을 띄운다.
        // 언제 물을지는 화면이 정한다(알람을 저장할 때, 또는 '알림 허용하기' 를 눌렀을 때).
        // 여기서는 이미 허락받았을 때만 건다.
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus != .notDetermined else {
            log.info("알림 권한을 아직 묻지 않아 로컬 백업을 걸지 않는다")
            return
        }
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        var scheduled = 0
        for alarm in alarms where alarm.isEnabled {
            for request in requests(for: alarm) {
                guard scheduled < maxScheduled else {
                    log.info("로컬 알림 한도에 닿아 나머지는 서버 푸시로만 온다")
                    return
                }
                do {
                    try await center.add(request)
                    scheduled += 1
                } catch {
                    log.error("로컬 알림을 걸지 못했다: \(String(describing: error), privacy: .private)")
                }
            }
        }
        log.info("로컬 백업 알림 \(scheduled)건을 걸었다")
    }

    private static func requests(for alarm: AlarmSetting) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? String(localized: "알람") : alarm.label
        content.body = String(localized: "\(alarm.sourceText) · 눌러서 재생하세요.")
        content.sound = .default
        content.categoryIdentifier = PushRegistrar.categoryID
        if #available(iOS 15.0, *) {
            // 집중 모드에서도 뜨게 한다. 권한이 없으면 iOS 가 조용히 보통 알림으로 내린다.
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
        }
        // 로컬 알림은 무엇을 틀지 기기가 이미 안다. 자동 선택이면 비워 두고 앱이 그때 고른다.
        var payload: [String: Any] = [
            "alarmID": alarm.serverAlarmID ?? alarm.localID.uuidString,
            "kind": alarm.sourceKind == .episode ? "episode" : "station",
            "local": true,
        ]
        if let item = alarm.playable {
            payload["id"] = item.id
            payload["title"] = item.title
        } else if let situation = alarm.situation {
            payload["situation"] = situation.rawValue
        }
        content.userInfo = ["zp": payload]

        let days = alarm.weekdays
        let ids = identifiers(for: alarm)

        if days.isEmpty {
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return [UNNotificationRequest(identifier: ids[0], content: content, trigger: trigger)]
        }

        return zip(days.sorted(), ids).map { day, id in
            var components = DateComponents()
            components.weekday = day
            components.hour = alarm.hour
            components.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }
    }

    /// 서버 푸시가 먼저 도착했으면 같은 알람의 로컬 백업을 지금 건만 치운다.
    ///
    /// 반복 알람은 예약을 없애면 다음 주에도 안 울린다. 그래서 예약은 그대로 두고
    /// 이미 배달돼 알림 센터에 쌓인 것만 지운다.
    static func cancelDelivered(serverAlarmID: String) {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            let ids = delivered
                .filter { note in
                    let zp = note.request.content.userInfo["zp"] as? [String: Any]
                    return (zp?["alarmID"] as? String) == serverAlarmID
                        && note.request.identifier.hasPrefix(prefix)
                }
                .map(\.request.identifier)
            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    /// '5분 뒤 다시'. 한 번만 울리는 알림을 새로 건다.
    static func scheduleSnooze(after seconds: TimeInterval, userInfo: [AnyHashable: Any]) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "다시 알림")
        content.body = String(localized: "눌러서 재생하세요.")
        content.sound = .default
        content.categoryIdentifier = PushRegistrar.categoryID
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(snoozePrefix)\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// 앱을 열면 밀린 스누즈를 치운다. 이미 일어난 사람에게 또 울릴 이유가 없다.
    static func cancelSnoozes() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ids = pending.map(\.identifier).filter { $0.hasPrefix(snoozePrefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ids = pending.map(\.identifier).filter {
                $0.hasPrefix(prefix) || $0.hasPrefix(snoozePrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
