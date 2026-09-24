import Foundation

/// `GET /zp/v1/alarms` 의 한 건.
struct AlarmDTO: Codable, Hashable, Sendable {
    struct Source: Codable, Hashable, Sendable {
        let kind: String
        let id: String?
        let title: String?
        let situation: String?
    }

    let alarmID: String
    let hour: Int
    let minute: Int
    let weekdays: [Int]
    let timezone: String
    let source: Source
    let label: String?
    let enabled: Bool
    /// 서버가 계산한 다음 발송 시각(UTC). 설정 화면에 그대로 보여 준다.
    let nextFireAt: String?
    let lastSentAt: String?
}

struct AlarmListDTO: Codable, Sendable {
    let items: [AlarmDTO]
}

struct AlarmCreatedDTO: Codable, Sendable {
    let alarmID: String
    let nextFireAt: String?
}

/// 알람을 만들거나 고칠 때 보내는 몸통.
struct AlarmPayload: Codable, Sendable {
    struct Source: Codable, Sendable {
        var kind: String
        var id: String?
        var title: String?
        var situation: String?
    }

    var hour: Int
    var minute: Int
    var weekdays: [Int]
    var timezone: String
    var label: String?
    var enabled: Bool
    var source: Source

    init(_ alarm: AlarmSetting) {
        hour = alarm.hour
        minute = alarm.minute
        weekdays = alarm.weekdays.sorted()
        timezone = alarm.timezoneID
        label = alarm.label
        enabled = alarm.isEnabled
        source = Source(
            kind: alarm.sourceKind.rawValue,
            id: alarm.sourceID,
            title: alarm.sourceTitle,
            situation: alarm.situation?.rawValue
        )
    }
}

/// 알림에서 꺼낸 "이제 무엇을 틀지".
///
/// 서버 푸시는 무엇을 틀지 이미 골라서 보낸다. 로컬 백업 알림은 기기가 만든 것이라
/// 자동 선택이면 소스가 비어 있고, 앱이 열린 뒤에 그때 고른다.
struct AlarmPushInfo: Sendable {
    let alarmID: String
    let item: PlayableItem?
    let situation: Situation?

    /// 알림 `userInfo` 에서 꺼낸다. 모양이 다르면 nil 이다.
    init?(userInfo: [AnyHashable: Any]) {
        guard
            let zp = userInfo["zp"] as? [String: Any],
            let alarmID = zp["alarmID"] as? String
        else { return nil }

        self.alarmID = alarmID
        self.situation = (zp["situation"] as? String).flatMap(Situation.init(rawValue:))

        if let id = zp["id"] as? String, !id.isEmpty, let title = zp["title"] as? String {
            self.item = PlayableItem(
                id: id,
                kind: (zp["kind"] as? String) == "episode" ? .podcast : .station,
                title: title,
                subtitle: String(localized: "알람")
            )
        } else {
            self.item = nil
        }

        // 틀 것도 상황도 없으면 알림을 눌러도 할 일이 없다.
        if item == nil && situation == nil { return nil }
    }
}
