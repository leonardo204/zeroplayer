import Foundation

/// 이 재생이 어디서 시작됐는지. 청취 기록에 그대로 남는다.
struct PlaybackOrigin: Equatable, Sendable {
    var presetName: String?
    var fromRecommendation: Bool

    init(presetName: String? = nil, fromRecommendation: Bool = false) {
        self.presetName = presetName
        self.fromRecommendation = fromRecommendation
    }

    /// 목록에서 직접 골라 누른 경우.
    static let manual = PlaybackOrigin()
}

/// 청취 기록을 남기는 통로. 재생 코드가 SwiftData 를 직접 알지 않게 떼어 놓는다.
@MainActor
protocol ListeningRecording: AnyObject {
    func begin(item: PlayableItem, origin: PlaybackOrigin)
    /// 앱이 갑자기 죽어도 들은 시간이 남게 중간중간 저장한다.
    func progress(_ elapsed: TimeInterval)
    func finish(_ elapsed: TimeInterval)
}
