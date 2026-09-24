import Foundation
import SwiftData
import os

/// 듣던 위치를 읽고 쓴다. 에피소드마다 한 줄만 둔다.
@MainActor
final class PositionStore: PlaybackPositionKeeping {
    /// 이만큼 못 들었으면 이어듣기로 보지 않는다. 눌렀다 바로 끈 것까지 남기면 지저분하다.
    static let minimumSeconds: TimeInterval = 30
    /// 끝에서 이만큼 안쪽이면 다 들은 것으로 보고 위치를 지운다.
    static let finishedTailSeconds: TimeInterval = 60

    private let context: ModelContext
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "position")

    init(context: ModelContext) {
        self.context = context
    }

    func position(for itemID: String) -> TimeInterval? {
        guard let row = row(itemID) else { return nil }
        guard row.seconds >= Self.minimumSeconds else { return nil }
        if row.duration > 0 && row.seconds >= row.duration - Self.finishedTailSeconds { return nil }
        return row.seconds
    }

    func save(item: PlayableItem, seconds: TimeInterval, duration: TimeInterval) {
        guard item.kind == .podcast else { return }

        // 거의 끝까지 들었으면 남기지 않는다. 다음에 열 때 처음부터 나오는 것이 맞다.
        if duration > 0 && seconds >= duration - Self.finishedTailSeconds {
            clear(itemID: item.id)
            return
        }
        guard seconds >= Self.minimumSeconds else { return }

        if let row = row(item.id) {
            row.seconds = seconds
            if duration > 0 { row.duration = duration }
            row.updatedAt = .now
        } else {
            context.insert(PlaybackPosition(item: item, seconds: seconds, duration: duration))
        }
        persist()
    }

    func clear(itemID: String) {
        guard let row = row(itemID) else { return }
        context.delete(row)
        persist()
    }

    /// 이어듣기 목록. 최근에 들은 것부터.
    func recent(limit: Int = 10) -> [PlaybackPosition] {
        var descriptor = FetchDescriptor<PlaybackPosition>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func row(_ itemID: String) -> PlaybackPosition? {
        var descriptor = FetchDescriptor<PlaybackPosition>(predicate: #Predicate { $0.itemID == itemID })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func persist() {
        do {
            try context.save()
        } catch {
            log.error("들은 위치를 저장하지 못했다: \(String(describing: error), privacy: .private)")
        }
    }
}
