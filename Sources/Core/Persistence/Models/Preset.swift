import Foundation
import SwiftData

/// 프리셋이 무엇을 재생할지. `.auto` 는 서버 규칙 추천에서 한 곳을 골라 온다.
enum PresetSourceKind: String, Codable, CaseIterable, Sendable {
    case station
    case auto

    var label: String {
        switch self {
        case .station: return "방송국 지정"
        case .auto: return "자동 선택"
        }
    }
}

/// 서버 `GET /recommend` 의 situation 값과 같다.
enum Situation: String, Codable, CaseIterable, Sendable {
    case sleep, commute, study, work, wake

    var label: String {
        switch self {
        case .sleep: return "취침"
        case .commute: return "운전"
        case .study: return "공부"
        case .work: return "작업"
        case .wake: return "기상"
        }
    }

    var symbolName: String {
        switch self {
        case .sleep: return "moon.zzz.fill"
        case .commute: return "car.fill"
        case .study: return "book.fill"
        case .work: return "laptopcomputer"
        case .wake: return "sunrise.fill"
        }
    }
}

@Model
final class Preset {
    @Attribute(.unique) var presetID: UUID
    var name: String
    var symbolName: String
    /// `PresetSourceKind` 의 원시값. SwiftData 에 열거형을 직접 넣지 않고 문자열로 둔다.
    var sourceKindRaw: String
    var sourceID: String?
    /// 방송국 이름. 목록을 못 불러도 프리셋 화면에 무엇이 걸려 있는지 보이게 저장해 둔다.
    var sourceTitle: String?
    var situationRaw: String
    /// 0 이면 타이머 없이 계속 재생한다.
    var timerMinutes: Int
    var fadeOutSeconds: Int
    var order: Int
    var createdAt: Date

    init(
        name: String,
        symbolName: String,
        sourceKind: PresetSourceKind,
        sourceID: String? = nil,
        sourceTitle: String? = nil,
        situation: Situation,
        timerMinutes: Int,
        fadeOutSeconds: Int,
        order: Int,
        createdAt: Date = .now
    ) {
        self.presetID = UUID()
        self.name = name
        self.symbolName = symbolName
        self.sourceKindRaw = sourceKind.rawValue
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.situationRaw = situation.rawValue
        self.timerMinutes = timerMinutes
        self.fadeOutSeconds = fadeOutSeconds
        self.order = order
        self.createdAt = createdAt
    }

    var sourceKind: PresetSourceKind {
        get { PresetSourceKind(rawValue: sourceKindRaw) ?? .auto }
        set { sourceKindRaw = newValue.rawValue }
    }

    var situation: Situation {
        get { Situation(rawValue: situationRaw) ?? .work }
        set { situationRaw = newValue.rawValue }
    }

    /// 프리셋 카드 두 번째 줄.
    var sourceDescription: String {
        switch sourceKind {
        case .auto: return "자동 선택 · \(situation.label)"
        case .station: return sourceTitle ?? "방송국을 고르지 않았습니다"
        }
    }

    var timerDescription: String? {
        guard timerMinutes > 0 else { return nil }
        return "\(timerMinutes)분"
    }
}

extension Preset {
    /// 처음 실행될 때 만들어 두는 다섯 개. 사용자가 이름과 내용을 바꿀 수 있다.
    static func defaults() -> [Preset] {
        [
            Preset(name: "취침", symbolName: "moon.zzz.fill", sourceKind: .auto,
                   situation: .sleep, timerMinutes: 45, fadeOutSeconds: 30, order: 0),
            Preset(name: "운전", symbolName: "car.fill", sourceKind: .auto,
                   situation: .commute, timerMinutes: 0, fadeOutSeconds: 10, order: 1),
            Preset(name: "공부", symbolName: "book.fill", sourceKind: .auto,
                   situation: .study, timerMinutes: 90, fadeOutSeconds: 30, order: 2),
            Preset(name: "작업", symbolName: "laptopcomputer", sourceKind: .auto,
                   situation: .work, timerMinutes: 0, fadeOutSeconds: 10, order: 3),
            Preset(name: "기상", symbolName: "sunrise.fill", sourceKind: .auto,
                   situation: .wake, timerMinutes: 30, fadeOutSeconds: 10, order: 4),
        ]
    }

    /// 프리셋 편집에서 고를 수 있는 아이콘. SF Symbols 만 쓴다.
    static let symbolChoices = [
        "moon.zzz.fill", "car.fill", "book.fill", "laptopcomputer", "sunrise.fill",
        "cup.and.saucer.fill", "figure.run", "bed.double.fill", "headphones",
        "music.note", "newspaper.fill", "leaf.fill", "sparkles", "star.fill",
    ]
}
