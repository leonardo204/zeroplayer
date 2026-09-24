import Foundation
import SwiftData

/// 알람 하나. 서버에도 같은 내용이 남아 기기를 바꿔도 유지된다.
///
/// 기기 안 사본을 따로 두는 이유는 둘이다. 네트워크가 없어도 목록이 보여야 하고,
/// 로컬 백업 알림을 예약하려면 앱이 내용을 알고 있어야 한다(`docs/01-features.md` 5.3).
@Model
final class AlarmSetting {
    @Attribute(.unique) var localID: UUID
    /// 서버가 준 `alm_...`. 서버에 못 닿은 채 만든 알람은 비어 있고, 다음 동기화에서 채워진다.
    var serverAlarmID: String?

    var hour: Int
    var minute: Int
    /// 1=일 … 7=토. 비어 있으면 다음 한 번만 울린다.
    var weekdaysRaw: String
    var timezoneID: String

    var sourceKindRaw: String
    var sourceID: String?
    var sourceTitle: String?
    var situationRaw: String?

    var label: String
    var isEnabled: Bool
    var createdAt: Date
    /// 서버에 반영하지 못한 변경이 남아 있는지. 다음에 앱을 열 때 다시 밀어 넣는다.
    var needsSync: Bool

    init(
        hour: Int = 7,
        minute: Int = 0,
        weekdays: Set<Int> = [2, 3, 4, 5, 6],
        timezoneID: String = TimeZone.current.identifier,
        sourceKind: AlarmSourceKind = .auto,
        sourceID: String? = nil,
        sourceTitle: String? = nil,
        situation: Situation? = .wake,
        label: String = "알람",
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.localID = UUID()
        self.hour = hour
        self.minute = minute
        self.weekdaysRaw = weekdays.sorted().map(String.init).joined(separator: ",")
        self.timezoneID = timezoneID
        self.sourceKindRaw = sourceKind.rawValue
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.situationRaw = situation?.rawValue
        self.label = label
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.needsSync = true
    }
}

enum AlarmSourceKind: String, Codable, CaseIterable, Sendable {
    case station
    case episode
    case auto

    var label: String {
        switch self {
        case .station: return "방송국 지정"
        case .episode: return "에피소드 지정"
        case .auto: return "자동 선택"
        }
    }
}

extension AlarmSetting {
    var weekdays: Set<Int> {
        get {
            Set(weekdaysRaw.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) })
        }
        set { weekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var sourceKind: AlarmSourceKind {
        get { AlarmSourceKind(rawValue: sourceKindRaw) ?? .auto }
        set { sourceKindRaw = newValue.rawValue }
    }

    var situation: Situation? {
        get { situationRaw.flatMap(Situation.init(rawValue:)) }
        set { situationRaw = newValue?.rawValue }
    }

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// '평일', '주말', '매일', 또는 '월·수·금'.
    var repeatText: String {
        let days = weekdays
        if days.isEmpty { return "한 번만" }
        if days == [2, 3, 4, 5, 6] { return "평일" }
        if days == [1, 7] { return "주말" }
        if days.count == 7 { return "매일" }
        let names = ["", "일", "월", "화", "수", "목", "금", "토"]
        return days.sorted().map { names[$0] }.joined(separator: "·")
    }

    var sourceText: String {
        switch sourceKind {
        case .auto: return "자동 선택 · \(situation?.label ?? "기상")"
        case .station, .episode: return sourceTitle ?? "고른 소스가 없습니다"
        }
    }

    /// 깨어나서 바로 틀 것. 자동 선택은 서버가 발송 시점에 고르므로 여기서는 비어 있다.
    var playable: PlayableItem? {
        guard let sourceID, sourceKind != .auto else { return nil }
        return PlayableItem(
            id: sourceID,
            kind: sourceKind == .episode ? .podcast : .station,
            title: sourceTitle ?? label,
            subtitle: label
        )
    }
}
