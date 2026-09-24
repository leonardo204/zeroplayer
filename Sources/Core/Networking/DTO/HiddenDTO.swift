import Foundation

/// `GET /zp/v1/hidden/channels` 의 한 건. 한국 지상파다.
struct HiddenChannelDTO: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let broadcaster: String
    let artworkURL: String?
    /// 편성표를 주는 채널인지. AFN 처럼 없는 곳은 채널 이름만 보여 준다.
    let hasSchedule: Bool

    var playable: PlayableItem {
        PlayableItem(
            id: id,
            kind: .hidden,
            title: name,
            subtitle: broadcaster,
            artworkURL: artworkURL.flatMap(URL.init(string:))
        )
    }
}

struct HiddenChannelListDTO: Codable, Sendable {
    let items: [HiddenChannelDTO]
}

struct HiddenUnlockDTO: Codable, Sendable {
    let token: String
    let alreadyUnlocked: Bool
}

/// `GET /zp/v1/hidden/channels/{id}/now`. 파싱이 실패하면 값이 전부 비어 온다.
struct HiddenNowDTO: Codable, Sendable {
    let programName: String?
    let startTime: String?
    let endTime: String?
    let artworkURL: String?
    let refreshAfter: Int

    var isEmpty: Bool { (programName ?? "").isEmpty }

    /// "15:00 ~ 16:00". 한쪽이라도 없으면 비운다.
    var timeRange: String? {
        guard let startTime, let endTime else { return nil }
        return "\(startTime) ~ \(endTime)"
    }
}
