import Foundation

/// `GET /zp/v1/recommend` 의 한 건.
struct RecommendationDTO: Codable, Hashable, Sendable {
    let kind: String
    let id: String
    let title: String
    let subtitle: String?
    /// 서버가 붙인 이유. M3 에서는 규칙 문구, M4 부터 LLM 문구가 온다.
    let reason: String?
    let artworkURL: String?
    let tags: [String]
    let moods: [String]
    let isSecure: Bool?

    var playable: PlayableItem {
        PlayableItem(
            id: id,
            kind: kind == "podcast" ? .podcast : .station,
            title: title,
            subtitle: subtitle,
            artworkURL: artworkURL.flatMap(URL.init(string:))
        )
    }
}

struct RecommendationSetDTO: Codable, Sendable {
    let situation: String
    let daypart: String
    let dayType: String
    let country: String?
    /// 'rule' 이면 규칙만 돈 결과다. M4 에서 'llm' 이 온다.
    let source: String
    let generatedAt: String
    let items: [RecommendationDTO]
}

struct RecommendQuery: Hashable, Sendable {
    var situation: Situation
    var country: String?
    var at: Date = .now
    var limit: Int = 20
    var secureOnly: Bool = false

    /// 서버는 현지 시각을 문자열 앞부분에서 읽는다.
    ///
    /// 오프셋(`+09:00`)을 붙이면 질의 문자열에서 `+` 가 공백으로 풀려 서버가 시각을 놓친다.
    /// 그래서 오프셋 없이 기기의 시계만 보낸다. 서버는 이 값을 그대로 현지 시각으로 읽는다.
    var atText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: at)
    }
}
