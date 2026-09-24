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
    /// 어느 상황에서 틀었는지(`Situation` 의 원시값). 직접 고른 재생은 비어 있다.
    ///
    /// M4 에서 더한 값이라 없을 수 있다. SwiftData 가 기존 저장소를 그대로 열도록
    /// 선택 속성으로 둔다.
    var situationRaw: String?

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
        self.situationRaw = origin.situation?.rawValue
    }

    var kind: SourceKind { SourceKind(rawValue: kindRaw) ?? .station }

    var situation: Situation? { situationRaw.flatMap(Situation.init(rawValue:)) }
}
