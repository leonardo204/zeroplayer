import Foundation
import Observation
import SwiftData
import os

/// 자동 선택에서 뺀 방송국 목록.
///
/// 기기가 기준이다. 서버에 못 올려도 기기 쪽 자동 선택은 곧바로 그 방송을 건너뛴다.
/// 못 올린 것은 `needsSync` 로 표시해 뒀다가 다음에 앱을 열 때 다시 밀어 넣는다.
///
/// **서버에 올리는 것은 iOS 25 이하뿐이다.** 거기서는 알람에 무엇을 틀지 서버가 고르므로
/// 기기에만 두면 아침에 그 방송이 그대로 온다. iOS 26 이상은 앱이 고르기 때문에 올릴
/// 이유가 없고, AlarmKit 권한을 받는 순간 서버에 둔 사본을 지운다(`AlarmDelivery`).
///
/// **앱에 하나만 둔다.** 화면이 쓸 때마다 새로 만들면 각자 다른 사본을 들고 있어서,
/// 설정에서 되돌린 것이 재생기 쪽에는 반영되지 않는다. 그래서 `@Observable` 로 두고
/// 환경으로 내려보낸다.
@MainActor
@Observable
final class ExcludedStore: StationExcluding {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let client: ProxyClienting
    @ObservationIgnored private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "exclude")

    /// 매번 SwiftData 를 묻지 않으려고 들고 있는 사본. 자동 선택이 후보마다 물어본다.
    private var cache: Set<String>

    /// 서버 사본을 지웠는지. 두 번 지우지 않으려고 둔다.
    private static let droppedKey = "zp.exclude.droppedForAlarmKit"

    init(context: ModelContext, client: ProxyClienting = ProxyClient()) {
        self.context = context
        self.client = client
        self.cache = Set(((try? context.fetch(FetchDescriptor<ExcludedStation>())) ?? []).map(\.itemID))
    }

    // MARK: - 읽기

    var excludedIDs: Set<String> { cache }

    func isExcluded(_ itemID: String) -> Bool { cache.contains(itemID) }

    var count: Int { cache.count }

    func all() -> [ExcludedStation] {
        let descriptor = FetchDescriptor<ExcludedStation>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 쓰기

    func exclude(_ item: PlayableItem) {
        // 라디오만 뺀다. 에피소드는 한 번 듣고 끝이라 목록에 남길 값이 없다.
        guard item.kind == .station else { return }
        guard !cache.contains(item.id) else { return }

        context.insert(ExcludedStation(itemID: item.id, title: item.title))
        cache.insert(item.id)
        save()
        log.info("자동 선택에서 뺐다: \(item.title, privacy: .public)")
        pushToServer()
    }

    /// 설정 화면에서 되돌린다.
    func restore(_ row: ExcludedStation) {
        cache.remove(row.itemID)
        context.delete(row)
        save()
        pushToServer()
    }

    func restoreAll() {
        for row in all() { context.delete(row) }
        cache.removeAll()
        save()
        log.info("제외 목록을 비웠다")
        pushToServer()
    }

    // MARK: - 서버와 맞추기

    /// 앱을 열 때 한 번. 밀린 것이 있으면 다시 올린다.
    func syncIfNeeded() {
        if AlarmDelivery.usesAlarmKit {
            dropServerCopyIfNeeded()
            return
        }
        // 서버 경로로 돌아왔으면 지웠다는 표시를 턴다. 다시 올려야 한다.
        UserDefaults.standard.set(false, forKey: Self.droppedKey)
        guard all().contains(where: \.needsSync) else { return }
        pushToServer()
    }

    /// 목록 전체를 서버에 덮어쓴다. 올리는 것은 방송국 번호뿐이다.
    private func pushToServer() {
        guard !AlarmDelivery.usesAlarmKit else { return }
        let rows = all()
        let ids = rows.map(\.itemID)
        let client = self.client
        Task { [weak self] in
            do {
                try await client.replaceExclusions(ids)
                guard let self else { return }
                for row in rows where row.needsSync { row.needsSync = false }
                self.save()
                self.log.info("제외 목록 \(ids.count)건을 서버에 맞췄다")
            } catch {
                // 기기 쪽은 이미 걸러내고 있다. 다음에 앱을 열 때 다시 올린다.
                self?.log.info("제외 목록을 서버에 못 올렸다: \(String(describing: error), privacy: .private)")
            }
        }
    }

    /// AlarmKit 으로 옮겼으면 서버에 둔 사본을 지운다. 서버가 더는 알 이유가 없다.
    private func dropServerCopyIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.droppedKey) else { return }
        let client = self.client
        Task { [weak self] in
            do {
                try await client.replaceExclusions([])
                UserDefaults.standard.set(true, forKey: Self.droppedKey)
                self?.log.info("AlarmKit 를 쓰므로 서버의 제외 목록을 지웠다")
            } catch {
                self?.log.info("서버의 제외 목록을 못 지웠다: \(String(describing: error), privacy: .private)")
            }
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            log.error("제외 목록을 저장하지 못했다: \(String(describing: error), privacy: .private)")
        }
    }
}
