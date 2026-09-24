import Foundation
import SwiftData

/// 프록시가 내려준 방송국 목록의 사본.
///
/// 네트워크가 없을 때 목록을 그대로 보여주려고 둔다. 스트림 주소는 담지 않는다 —
/// 주소는 재생 직전에만 받고 저장하지 않는다는 원칙 때문에, 오프라인에서는 목록만 보이고
/// 재생은 안 된다.
@Model
final class CachedStation {
    /// `조회조건#방송국ID`. 같은 방송국이 여러 목록에 들어가도 줄이 겹치지 않는다.
    @Attribute(.unique) var key: String
    var stationID: String
    var cacheKey: String
    var order: Int

    var name: String
    var countryCode: String?
    var language: String?
    var codec: String?
    var bitrate: Int
    var votes: Int
    var clicks: Int
    var artwork: String?
    var homepage: String?
    var tagsJoined: String
    var isSecure: Bool
    var updatedAt: String
    var cachedAt: Date

    init(dto: StationDTO, cacheKey: String, order: Int, cachedAt: Date = .now) {
        self.key = "\(cacheKey)#\(dto.id)"
        self.stationID = dto.id
        self.cacheKey = cacheKey
        self.order = order
        self.name = dto.name
        self.countryCode = dto.countryCode
        self.language = dto.language
        self.codec = dto.codec
        self.bitrate = dto.bitrate
        self.votes = dto.votes
        self.clicks = dto.clicks
        self.artwork = dto.artworkURL
        self.homepage = dto.homepage
        self.tagsJoined = dto.tags.joined(separator: ",")
        self.isSecure = dto.isSecure ?? true
        self.updatedAt = dto.updatedAt
        self.cachedAt = cachedAt
    }

    var dto: StationDTO {
        StationDTO(
            id: stationID,
            name: name,
            countryCode: countryCode,
            language: language,
            codec: codec,
            bitrate: bitrate,
            votes: votes,
            clicks: clicks,
            artworkURL: artwork,
            homepage: homepage,
            tags: tagsJoined.isEmpty ? [] : tagsJoined.components(separatedBy: ","),
            isSecure: isSecure,
            updatedAt: updatedAt
        )
    }
}
