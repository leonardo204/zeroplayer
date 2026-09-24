import Foundation
import SwiftData

/// 에피소드를 어디까지 들었는지. 앱을 끄고 다시 열어도 이어듣게 하려고 둔다.
@Model
final class PlaybackPosition {
    @Attribute(.unique) var itemID: String
    var title: String
    var podcastTitle: String?
    var feedID: String?
    var seconds: TimeInterval
    var duration: TimeInterval
    var updatedAt: Date

    init(item: PlayableItem, seconds: TimeInterval, duration: TimeInterval, updatedAt: Date = .now) {
        self.itemID = item.id
        self.title = item.title
        self.podcastTitle = item.subtitle
        self.feedID = item.feedID
        self.seconds = seconds
        self.duration = duration
        self.updatedAt = updatedAt
    }

    /// 어디까지 왔는지. 진행 바에 쓴다.
    var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, seconds / duration))
    }

    var remainingText: String? {
        guard duration > seconds else { return nil }
        let minutes = Int((duration - seconds) / 60)
        return minutes <= 0 ? "1분 미만 남음" : "\(minutes)분 남음"
    }
}
