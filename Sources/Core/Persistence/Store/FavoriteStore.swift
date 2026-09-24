import Foundation
import SwiftData
import os

/// 즐겨찾기를 넣고 빼는 자리. 화면은 `@Query` 로 목록을 읽고 바꿀 때만 이걸 부른다.
@MainActor
struct FavoriteStore {
    private let context: ModelContext
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "favorite")

    init(context: ModelContext) {
        self.context = context
    }

    func contains(_ itemID: String) -> Bool {
        var descriptor = FetchDescriptor<Favorite>(predicate: #Predicate { $0.itemID == itemID })
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor))?.isEmpty == false)
    }

    /// 넣으면 true, 뺐으면 false 를 준다.
    @discardableResult
    func toggle(_ item: PlayableItem) -> Bool {
        let id = item.id
        var descriptor = FetchDescriptor<Favorite>(predicate: #Predicate { $0.itemID == id })
        descriptor.fetchLimit = 1
        let existing = (try? context.fetch(descriptor))?.first

        if let existing {
            context.delete(existing)
            save()
            return false
        }
        context.insert(Favorite(item: item))
        save()
        return true
    }

    func all() -> [Favorite] {
        let descriptor = FetchDescriptor<Favorite>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func save() {
        do {
            try context.save()
        } catch {
            log.error("즐겨찾기를 저장하지 못했다: \(String(describing: error), privacy: .private)")
        }
    }
}
