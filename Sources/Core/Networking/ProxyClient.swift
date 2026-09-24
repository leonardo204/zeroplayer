import Foundation
import os

/// 앱이 부르는 서버는 이것 하나뿐이다.
/// radio-browser·Podcast Index·방송사 주소는 앱에 없다.
protocol ProxyClienting: StreamReporting, Sendable {
    func stations(_ query: StationQuery) async throws -> StationPageDTO
    func streamURL(stationID: String) async throws -> StreamDTO
    func facets() async throws -> FacetsDTO
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

enum ProxyError: Error, LocalizedError {
    case offline
    case badStatus(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .offline: "네트워크에 닿지 못했습니다."
        case .badStatus(let code): "서버가 \(code) 로 답했습니다."
        case .decoding: "서버 응답을 읽지 못했습니다."
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

    func streamURL(stationID: String) async throws -> StreamDTO {
        try await get("/stations/\(stationID)/stream")
    }

    func facets() async throws -> FacetsDTO {
        try await get("/stations/facets")
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

    // MARK: - 공통

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let request = makeRequest(path: path, query: query)
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

    private func makeRequest(path: String, query: [URLQueryItem]) -> URLRequest {
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
        return request
    }
}
