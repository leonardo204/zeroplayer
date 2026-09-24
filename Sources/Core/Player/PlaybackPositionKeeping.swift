import Foundation

/// 듣던 위치를 남기는 통로. 재생 코드가 SwiftData 를 직접 알지 않게 떼어 놓는다.
///
/// 라디오는 이어들을 위치가 없다. 에피소드에만 쓴다.
@MainActor
protocol PlaybackPositionKeeping: AnyObject {
    func position(for itemID: String) -> TimeInterval?
    func save(item: PlayableItem, seconds: TimeInterval, duration: TimeInterval)
    func clear(itemID: String)
}
