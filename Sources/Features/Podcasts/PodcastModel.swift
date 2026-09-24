import Foundation
import Observation
import os

/// 팟캐스트 목록 화면의 상태. 인기 목록과 검색 결과를 같은 목록에 담는다.
@MainActor
@Observable
final class PodcastModel {
    private(set) var items: [PodcastDTO] = []
    private(set) var isLoading = false
    private(set) var errorText: String?
    /// 서버가 무엇으로 만든 목록인지. 'local' 이면 서버가 이미 받아 둔 것 중에서 찾은 것이다.
    private(set) var source: String?
    var search = ""

    private let client: ProxyClienting
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "podcast")

    init(client: ProxyClienting = ProxyClient()) {
        self.client = client
    }

    private var country: String? { Locale.current.region?.identifier }

    func load() async {
        let term = search.trimmingCharacters(in: .whitespaces)
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let page = term.count >= 2
                ? try await client.searchPodcasts(term: term, country: country, limit: 30)
                : try await client.trendingPodcasts(country: country, limit: 30)
            items = page.items
            source = page.source
            log.info("팟캐스트 \(page.items.count)개 (\(page.source, privacy: .public))")
        } catch {
            items = []
            source = nil
            guard !isCancellation(error) else { return }
            errorText = (error as? ProxyError)?.errorDescription ?? String(localized: "팟캐스트를 가져오지 못했습니다.")
        }
    }
}

/// 한 팟캐스트의 에피소드 목록 상태.
@MainActor
@Observable
final class EpisodeListModel {
    private(set) var episodes: [EpisodeDTO] = []
    private(set) var podcast: PodcastDTO?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorText: String?

    private var nextCursor: String?
    private let client: ProxyClienting

    init(client: ProxyClienting = ProxyClient()) {
        self.client = client
    }

    func load(feedID: String) async {
        guard episodes.isEmpty else { return }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let page = try await client.episodes(feedID: feedID, cursor: nil, limit: 50)
            podcast = page.podcast
            episodes = page.items
            nextCursor = page.nextCursor
        } catch {
            guard !isCancellation(error) else { return }
            errorText = (error as? ProxyError)?.errorDescription ?? String(localized: "에피소드를 가져오지 못했습니다.")
        }
    }

    func loadMoreIfNeeded(current episode: EpisodeDTO, feedID: String) async {
        guard !isLoadingMore, let cursor = nextCursor, episode.id == episodes.last?.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await client.episodes(feedID: feedID, cursor: cursor, limit: 50) else { return }
        let known = Set(episodes.map(\.id))
        episodes.append(contentsOf: page.items.filter { !known.contains($0.id) })
        nextCursor = page.nextCursor
    }
}
