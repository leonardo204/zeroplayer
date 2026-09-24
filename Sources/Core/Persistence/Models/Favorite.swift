import Foundation
import SwiftData

/// 즐겨찾기. 전부 기기 안에만 둔다.
@Model
final class Favorite {
    @Attribute(.unique) var itemID: String
    var kindRaw: String
    var title: String
    var subtitle: String?
    var artwork: String?
    var addedAt: Date

    init(item: PlayableItem, addedAt: Date = .now) {
        self.itemID = item.id
        self.kindRaw = item.kind.rawValue
        self.title = item.title
        self.subtitle = item.subtitle
        self.artwork = item.artworkURL?.absoluteString
        self.addedAt = addedAt
    }

    var kind: SourceKind { SourceKind(rawValue: kindRaw) ?? .station }

    var playable: PlayableItem {
        PlayableItem(
            id: itemID,
            kind: kind,
            title: title,
            subtitle: subtitle,
            artworkURL: artwork.flatMap(URL.init(string:))
        )
    }
}
