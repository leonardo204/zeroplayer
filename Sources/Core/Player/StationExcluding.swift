import Foundation

/// 자동 선택에서 뺀 방송국을 읽고 쓰는 통로.
/// 재생 코드가 SwiftData 를 직접 알지 않게 떼어 놓는다(`PlaybackPositionKeeping` 과 같은 결).
@MainActor
protocol StationExcluding: AnyObject {
    /// 자동 선택이 이 방송을 건너뛰어야 하는지.
    func isExcluded(_ itemID: String) -> Bool
    /// 지금 걸러야 할 번호 전부. 후보 목록을 한 번에 훑을 때 쓴다.
    var excludedIDs: Set<String> { get }
    /// 목록에서 뺀다. 이미 있으면 아무 일도 하지 않는다.
    func exclude(_ item: PlayableItem)
}
