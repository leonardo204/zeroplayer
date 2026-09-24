import Foundation
import SwiftData
import os

/// 방송국 목록을 가져오고, 가져온 것을 캐시에 남기고, 네트워크가 없으면 캐시를 내준다.
@MainActor
final class StationStore {
    struct Page {
        var items: [StationDTO]
        var nextCursor: String?
        var fromCache: Bool
    }

    private let client: ProxyClienting
    private let context: ModelContext
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "stations")

    init(client: ProxyClienting = ProxyClient(), context: ModelContext) {
        self.client = client
        self.context = context
    }

    func page(_ query: StationQuery) async throws -> Page {
        do {
            let page = try await client.stations(query)
            if query.isCacheable {
                save(page.items, cacheKey: query.cacheKey, replacing: query.cursor == nil)
            }
            return Page(items: page.items, nextCursor: page.nextCursor, fromCache: false)
        } catch {
            // 우리가 취소한 요청은 실패가 아니다. 캐시를 꺼내면 새 조건으로 다시 부른
            // 목록 위에 옛 목록이 덮어씌워진다.
            guard !isCancellation(error) else { throw error }
            guard query.isCacheable, query.cursor == nil else { throw error }
            let cached = cached(cacheKey: query.cacheKey)
            guard !cached.isEmpty else { throw error }
            log.info("네트워크 실패로 캐시 \(cached.count)건을 쓴다")
            return Page(items: cached, nextCursor: nil, fromCache: true)
        }
    }

    func facets() async throws -> FacetsDTO {
        try await client.facets()
    }

    func reportDeadStream(stationID: String, reason: String) async {
        await client.reportDeadStream(stationID: stationID, reason: reason)
    }

    // MARK: - 캐시

    private func cached(cacheKey: String) -> [StationDTO] {
        var descriptor = FetchDescriptor<CachedStation>(
            predicate: #Predicate { $0.cacheKey == cacheKey },
            sortBy: [SortDescriptor(\.order)]
        )
        descriptor.fetchLimit = 300
        return ((try? context.fetch(descriptor)) ?? []).map(\.dto)
    }

    private func save(_ items: [StationDTO], cacheKey: String, replacing: Bool) {
        do {
            if replacing {
                try context.delete(model: CachedStation.self, where: #Predicate { $0.cacheKey == cacheKey })
            }
            let base = replacing ? 0 : nextOrder(cacheKey: cacheKey)
            for (offset, dto) in items.enumerated() {
                context.insert(CachedStation(dto: dto, cacheKey: cacheKey, order: base + offset))
            }
            try context.save()
        } catch {
            log.error("캐시 저장 실패: \(String(describing: error), privacy: .private)")
        }
    }

    private func nextOrder(cacheKey: String) -> Int {
        var descriptor = FetchDescriptor<CachedStation>(
            predicate: #Predicate { $0.cacheKey == cacheKey },
            sortBy: [SortDescriptor(\.order, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor))?.first?.order ?? -1) + 1
    }
}
