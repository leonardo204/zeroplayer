import Foundation

/// `GET /zp/v1/podcasts/...` 의 팟캐스트 한 건.
struct PodcastDTO: Codable, Hashable, Sendable, Identifiable {
    let feedID: String
    let title: String
    let author: String?
    let artworkURL: String?
    let language: String?
    let country: String?
    let categories: [String]
    let description: String?
    let episodeCount: Int

    var id: String { feedID }

    /// 목록 두 번째 줄.
    var subtitleText: String? {
        var parts: [String] = []
        if let author, !author.isEmpty { parts.append(author) }
        if let first = categories.first { parts.append(first) }
        if episodeCount > 0 { parts.append("\(episodeCount)편") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 에피소드 한 건. 오디오 주소는 여기 오지 않는다 — 재생 직전에 따로 묻는다.
struct EpisodeDTO: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let feedID: String
    let title: String
    let podcastTitle: String
    let durationSeconds: Int
    let publishedAt: String?
    let description: String?
    let artworkURL: String?
    let isSecure: Bool?

    var playable: PlayableItem {
        PlayableItem(
            id: id,
            kind: .podcast,
            title: title,
            subtitle: podcastTitle,
            artworkURL: artworkURL.flatMap(URL.init(string:)),
            durationSeconds: durationSeconds > 0 ? TimeInterval(durationSeconds) : nil,
            feedID: feedID
        )
    }

    var runtimeText: String? {
        guard durationSeconds > 0 else { return nil }
        let minutes = durationSeconds / 60
        return minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분"
    }

    var publishedText: String? {
        guard let publishedAt, let date = ISO8601DateFormatter().date(from: publishedAt) else { return nil }
        return date.formatted(.dateTime.year().month().day())
    }
}

struct PodcastListDTO: Codable, Sendable {
    let source: String
    let items: [PodcastDTO]
}

struct EpisodePageDTO: Codable, Sendable {
    let podcast: PodcastDTO
    let items: [EpisodeDTO]
    let nextCursor: String?
}
