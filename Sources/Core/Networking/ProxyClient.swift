import Foundation
import os

/// 앱이 부르는 서버는 이것 하나뿐이다.
/// radio-browser·Podcast Index·방송사 주소는 앱에 없다.
protocol ProxyClienting: StreamReporting, Sendable {
    func stations(_ query: StationQuery) async throws -> StationPageDTO
    /// 방송국 한 건. 프리셋·알람처럼 목록을 거치지 않고 튼 자리에서 썸네일을 채우려고 쓴다.
    func station(id: String) async throws -> StationDTO
    func streamURL(stationID: String) async throws -> StreamDTO
    func facets() async throws -> FacetsDTO
    func recommendations(_ query: RecommendQuery) async throws -> RecommendationSetDTO
    func registerPushToken(_ token: String, sandbox: Bool) async throws
    func deletePushToken() async throws
    func alarms() async throws -> [AlarmDTO]
    func createAlarm(_ payload: AlarmPayload) async throws -> AlarmCreatedDTO
    func updateAlarm(id: String, payload: AlarmPayload) async throws -> AlarmCreatedDTO
    func deleteAlarm(id: String) async throws
    func unlockHidden() async throws -> HiddenUnlockDTO
    func lockHidden(token: String) async throws
    func hiddenChannels(token: String) async throws -> HiddenChannelListDTO
    func hiddenStreamURL(channelID: String, token: String) async throws -> StreamDTO
    func hiddenNow(channelID: String, token: String) async throws -> HiddenNowDTO
    func trendingPodcasts(country: String?, limit: Int) async throws -> PodcastListDTO
    func searchPodcasts(term: String, country: String?, limit: Int) async throws -> PodcastListDTO
    func episodes(feedID: String, cursor: String?, limit: Int) async throws -> EpisodePageDTO
    func episodeStream(episodeID: String) async throws -> StreamDTO
}

struct StationQuery: Hashable, Sendable {
    var country: String?
    var tag: String?
    var language: String?
    var search: String?
    var sort: String = "popular"
    var limit: Int = 50
    var cursor: String?

    /// 캐시를 나누는 이름. 같은 조건이면 같은 문자열이 나온다.
    var cacheKey: String {
        [
            country ?? "-",
            tag ?? "-",
            language ?? "-",
            (search?.isEmpty == false) ? "q" : "-",
            sort,
        ].joined(separator: "|")
    }

    var isCacheable: Bool {
        (search?.isEmpty ?? true) && tag == nil && language == nil && sort == "popular"
    }
}

/// 본문이 필요 없는 POST 에 쓴다. `{}` 하나만 나간다.
private struct EmptyBody: Encodable {}

enum ProxyError: Error, LocalizedError {
    case offline
    case badStatus(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .offline: String(localized: "네트워크에 닿지 못했습니다.")
        case .badStatus(let code): String(localized: "서버가 \(code) 로 답했습니다.")
        case .decoding: String(localized: "서버 응답을 읽지 못했습니다.")
        }
    }
}

struct ProxyClient: ProxyClienting {
    private let baseURL: URL
    private let session: URLSession
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "proxy")

    init(baseURL: URL = AppConfig.proxyBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - 엔드포인트

    func stations(_ query: StationQuery) async throws -> StationPageDTO {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(query.limit))]
        if let country = query.country { items.append(.init(name: "country", value: country)) }
        if let tag = query.tag { items.append(.init(name: "tag", value: tag)) }
        if let language = query.language { items.append(.init(name: "lang", value: language)) }
        if let search = query.search, !search.isEmpty { items.append(.init(name: "q", value: search)) }
        if let cursor = query.cursor { items.append(.init(name: "cursor", value: cursor)) }
        items.append(.init(name: "sort", value: query.sort))
        return try await get("/stations", query: items)
    }

    func station(id: String) async throws -> StationDTO {
        try await get("/stations/\(id)")
    }

    func streamURL(stationID: String) async throws -> StreamDTO {
        try await get("/stations/\(stationID)/stream")
    }

    func facets() async throws -> FacetsDTO {
        try await get("/stations/facets")
    }

    func recommendations(_ query: RecommendQuery) async throws -> RecommendationSetDTO {
        var items: [URLQueryItem] = [
            .init(name: "situation", value: query.situation.rawValue),
            .init(name: "at", value: query.atText),
            .init(name: "limit", value: String(query.limit)),
        ]
        if let country = query.country { items.append(.init(name: "country", value: country)) }
        if query.secureOnly { items.append(.init(name: "secure", value: "1")) }
        if query.timerMinutes > 0 { items.append(.init(name: "timer", value: String(query.timerMinutes))) }
        items.append(.init(name: "lang", value: AppConfig.serverLanguage))
        return try await get("/recommend", query: items)
    }

    // MARK: - 팟캐스트

    func trendingPodcasts(country: String?, limit: Int) async throws -> PodcastListDTO {
        var items: [URLQueryItem] = [.init(name: "limit", value: String(limit))]
        if let country { items.append(.init(name: "country", value: country)) }
        return try await get("/podcasts/trending", query: items)
    }

    func searchPodcasts(term: String, country: String?, limit: Int) async throws -> PodcastListDTO {
        var items: [URLQueryItem] = [
            .init(name: "q", value: term),
            .init(name: "limit", value: String(limit)),
        ]
        if let country { items.append(.init(name: "country", value: country)) }
        return try await get("/podcasts/search", query: items)
    }

    func episodes(feedID: String, cursor: String?, limit: Int) async throws -> EpisodePageDTO {
        var items: [URLQueryItem] = [.init(name: "limit", value: String(limit))]
        if let cursor { items.append(.init(name: "cursor", value: cursor)) }
        return try await get("/podcasts/\(feedID)/episodes", query: items)
    }

    func episodeStream(episodeID: String) async throws -> StreamDTO {
        try await get("/episodes/\(episodeID)/stream")
    }

    // MARK: - 알람

    func registerPushToken(_ token: String, sandbox: Bool) async throws {
        try await send("/push/token", method: "POST", body: [
            "token": token,
            "env": sandbox ? "sandbox" : "prod",
            "appVersion": AppConfig.appVersion,
            "lang": AppConfig.serverLanguage,
        ])
    }

    func deletePushToken() async throws {
        try await send("/push/token", method: "DELETE", body: nil)
    }

    func alarms() async throws -> [AlarmDTO] {
        let list: AlarmListDTO = try await get("/alarms")
        return list.items
    }

    func createAlarm(_ payload: AlarmPayload) async throws -> AlarmCreatedDTO {
        try await sendJSON("/alarms", method: "POST", payload: payload)
    }

    func updateAlarm(id: String, payload: AlarmPayload) async throws -> AlarmCreatedDTO {
        try await sendJSON("/alarms/\(id)", method: "PATCH", payload: payload)
    }

    func deleteAlarm(id: String) async throws {
        try await send("/alarms/\(id)", method: "DELETE", body: nil)
    }

    /// 신고는 실패해도 사용자에게 알리지 않는다. 재생 복구가 먼저다.
    func reportDeadStream(stationID: String, reason: String) async {
        var request = makeRequest(path: "/stations/\(stationID)/report", query: [])
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["reason": reason])
        do {
            _ = try await session.data(for: request)
        } catch {
            log.debug("스트림 신고를 보내지 못했다: \(String(describing: error), privacy: .private)")
        }
    }

    // MARK: - 히든 (한국 지상파)

    /// 해제 토큰을 받는다. 이미 해제된 설치는 같은 토큰을 다시 준다.
    func unlockHidden() async throws -> HiddenUnlockDTO {
        try await sendJSON("/hidden/unlock", method: "POST", payload: EmptyBody())
    }

    func lockHidden(token: String) async throws {
        try await send("/hidden/lock", method: "POST", body: nil, hiddenToken: token)
    }

    func hiddenChannels(token: String) async throws -> HiddenChannelListDTO {
        try await get("/hidden/channels", hiddenToken: token)
    }

    /// 재생 직전에만 부른다. 방송사 주소는 저장하지 않는다.
    func hiddenStreamURL(channelID: String, token: String) async throws -> StreamDTO {
        try await get("/hidden/channels/\(channelID)/stream", hiddenToken: token)
    }

    func hiddenNow(channelID: String, token: String) async throws -> HiddenNowDTO {
        try await get("/hidden/channels/\(channelID)/now", hiddenToken: token)
    }

    // MARK: - 공통

    /// 응답 본문을 읽지 않는 요청. 실패는 그대로 던진다.
    private func send(_ path: String, method: String, body: [String: Any]?, hiddenToken: String? = nil) async throws {
        var request = makeRequest(path: path, query: [], hiddenToken: hiddenToken)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ProxyError.decoding }
            guard (200..<300).contains(http.statusCode) else { throw ProxyError.badStatus(http.statusCode) }
        } catch let error as ProxyError {
            throw error
        } catch {
            throw ProxyError.offline
        }
    }

    /// 구조체를 보내고 구조체를 받는 요청.
    private func sendJSON<Body: Encodable, T: Decodable>(
        _ path: String, method: String, payload: Body
    ) async throws -> T {
        var request = makeRequest(path: path, query: [])
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(payload)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ProxyError.decoding }
            guard (200..<300).contains(http.statusCode) else { throw ProxyError.badStatus(http.statusCode) }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ProxyError.decoding
            }
        } catch let error as ProxyError {
            throw error
        } catch {
            throw ProxyError.offline
        }
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], hiddenToken: String? = nil) async throws -> T {
        let request = makeRequest(path: path, query: query, hiddenToken: hiddenToken)
        log.debug("요청 \(request.url?.absoluteString ?? "-", privacy: .private)")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ProxyError.decoding }
            guard (200..<300).contains(http.statusCode) else { throw ProxyError.badStatus(http.statusCode) }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                log.error("응답 해석 실패 \(path, privacy: .public): \(String(describing: error), privacy: .private)")
                throw ProxyError.decoding
            }
        } catch let error as ProxyError {
            throw error
        } catch {
            throw ProxyError.offline
        }
    }

    private func makeRequest(path: String, query: [URLQueryItem], hiddenToken: String? = nil) -> URLRequest {
        // 방송국 ID 에 콜론이 들어간다('rb:<uuid>'). appendingPathComponent 로 붙이면
        // 이미 인코딩된 문자를 한 번 더 인코딩해 서버가 못 알아본다. 경로를 직접 넣는다.
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/zp/v1" + path
        if !query.isEmpty { components?.queryItems = query }
        var request = URLRequest(url: components?.url ?? baseURL)
        request.timeoutInterval = 15
        request.setValue("ios/\(AppConfig.appVersion)", forHTTPHeaderField: "X-ZP-Client")
        request.setValue(InstallIdentity.current, forHTTPHeaderField: "X-ZP-Install")
        request.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
        // 히든 경로에서만 붙는다. 공개 경로에는 실어 보내지 않는다.
        if let hiddenToken { request.setValue(hiddenToken, forHTTPHeaderField: "X-ZP-Hidden") }
        return request
    }
}
