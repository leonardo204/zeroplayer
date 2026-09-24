import Foundation
import SwiftData

/// 재생 한 번의 기록. 서버로 보내지 않는다. 추천 재정렬(M4)과 기록 탭이 이 표를 읽는다.
@Model
final class ListeningSession {
    var itemID: String
    var kindRaw: String
    var title: String
    var startedAt: Date
    var duration: TimeInterval
    var presetName: String?
    /// 추천 목록이나 프리셋의 자동 선택에서 시작했는지. 추천 품질 지표에 쓴다.
    var fromRecommendation: Bool
    /// 30초 안에 넘겼는지.
    var skippedEarly: Bool

    init(
        item: PlayableItem,
        origin: PlaybackOrigin,
        startedAt: Date = .now,
        duration: TimeInterval = 0
    ) {
        self.itemID = item.id
        self.kindRaw = item.kind.rawValue
        self.title = item.title
        self.startedAt = startedAt
        self.duration = duration
        self.presetName = origin.presetName
        self.fromRecommendation = origin.fromRecommendation
        self.skippedEarly = false
    }

    var kind: SourceKind { SourceKind(rawValue: kindRaw) ?? .station }
}
