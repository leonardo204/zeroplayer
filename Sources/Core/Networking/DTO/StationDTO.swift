import Foundation

/// `GET /zp/v1/stations` 의 한 건.
struct StationDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let countryCode: String?
    let language: String?
    let codec: String?
    let bitrate: Int
    let votes: Int
    let clicks: Int
    let artworkURL: String?
    let homepage: String?
    let tags: [String]
    /// 스트림이 HTTPS 인지. 평문 HTTP 를 못 여는 기기에서 걸러 내려고 서버가 알려 준다.
    let isSecure: Bool?
    let updatedAt: String
}

struct StationPageDTO: Codable, Sendable {
    let items: [StationDTO]
    let nextCursor: String?
}

/// `GET /zp/v1/stations/{id}/stream`. 앱은 이 값을 저장하지 않는다.
struct StreamDTO: Codable, Sendable {
    let url: String
    let codec: String?
    let bitrate: Int
    let recheckAfter: Int
    let degraded: Bool?
    /// 에피소드일 때만 온다. 라디오는 길이가 없다.
    let durationSeconds: Int?
}

struct FacetValueDTO: Codable, Hashable, Sendable {
    let value: String
    let count: Int
}

struct FacetsDTO: Codable, Sendable {
    let countries: [FacetValueDTO]
    let languages: [FacetValueDTO]
    let tags: [FacetValueDTO]
}

extension StationDTO {
    /// 방송국을 재생 대상으로 옮긴다. 재생 코드는 종류를 구분하지 않는다.
    var playable: PlayableItem {
        PlayableItem(
            id: id,
            kind: .station,
            title: name,
            subtitle: subtitleText,
            artworkURL: artworkURL.flatMap(URL.init(string:))
        )
    }

    private var subtitleText: String? {
        var parts: [String] = []
        if let countryCode, !countryCode.isEmpty { parts.append(countryCode) }
        if !tags.isEmpty { parts.append(tags.prefix(2).joined(separator: " · ")) }
        if bitrate > 0 { parts.append("\(bitrate)k") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
