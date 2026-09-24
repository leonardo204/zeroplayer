import Foundation
import Observation

/// 탐색 탭이 보고 있는 목록 상태.
@MainActor
@Observable
final class DiscoverModel {
    var items: [StationDTO] = []
    var facets: FacetsDTO?
    var isLoading = false
    var isLoadingMore = false
    var fromCache = false
    var errorText: String?

    var country: String? = DiscoverModel.defaultCountry
    var tag: String?
    var search = ""

    private var nextCursor: String?

    private static var defaultCountry: String? {
        Locale.current.region?.identifier ?? "KR"
    }

    private var query: StationQuery {
        StationQuery(
            country: country,
            tag: tag,
            language: nil,
            search: search.trimmingCharacters(in: .whitespaces),
            sort: "popular",
            limit: 50,
            cursor: nil
        )
    }

    func refresh(using store: StationStore) async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let page = try await store.page(query)
            items = page.items
            nextCursor = page.nextCursor
            fromCache = page.fromCache
        } catch {
            items = []
            nextCursor = nil
            guard !isCancellation(error) else { return }
            errorText = (error as? ProxyError)?.errorDescription ?? String(localized: "목록을 가져오지 못했습니다.")
        }
    }

    func loadMoreIfNeeded(current item: StationDTO, using store: StationStore) async {
        guard !isLoadingMore, let cursor = nextCursor,
              item.id == items.last?.id
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        var next = query
        next.cursor = cursor
        guard let page = try? await store.page(next) else { return }
        let known = Set(items.map(\.id))
        items.append(contentsOf: page.items.filter { !known.contains($0.id) })
        nextCursor = page.nextCursor
    }

    func loadFacetsIfNeeded(using store: StationStore) async {
        guard facets == nil else { return }
        facets = try? await store.facets()
    }
}
