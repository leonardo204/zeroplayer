import Foundation
import SwiftData
import os

/// 청취 기록을 쓰고 읽는다. 재생 주체가 `ListeningRecording` 으로만 부른다.
@MainActor
final class ListeningStore: ListeningRecording {
    private let context: ModelContext
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "listening")

    /// 지금 열려 있는 기록. 재생이 끝나거나 다른 소스로 넘어갈 때 닫는다.
    private var open: ListeningSession?
    private var lastSavedDuration: TimeInterval = 0

    /// 30초를 넘겨야 '들었다'로 본다. `docs/04-curation.md` 6번의 지표와 같은 기준이다.
    static let earlySkipSeconds: TimeInterval = 30
    /// 중간 저장 주기. 앱이 죽어도 이 간격만큼만 잃는다.
    private static let saveEvery: TimeInterval = 30

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 쓰기

    func begin(item: PlayableItem, origin: PlaybackOrigin) {
        finish(lastSavedDuration)

        let session = ListeningSession(item: item, origin: origin)
        context.insert(session)
        open = session
        lastSavedDuration = 0
        save()
        log.info("기록 시작: \(item.title, privacy: .public) (프리셋 \(origin.presetName ?? "-", privacy: .public))")
    }

    func progress(_ elapsed: TimeInterval) {
        guard let open, elapsed - lastSavedDuration >= Self.saveEvery else { return }
        open.duration = elapsed
        lastSavedDuration = elapsed
        save()
    }

    func finish(_ elapsed: TimeInterval) {
        guard let session = open else { return }
        session.duration = max(elapsed, session.duration)
        session.skippedEarly = session.duration < Self.earlySkipSeconds
        open = nil
        lastSavedDuration = 0
        save()
        log.info("기록 종료: \(session.title, privacy: .public) \(Int(session.duration))초 넘김=\(session.skippedEarly)")
    }

    private func save() {
        do {
            try context.save()
        } catch {
            log.error("청취 기록을 저장하지 못했다: \(String(describing: error), privacy: .private)")
        }
    }

    // MARK: - 읽기

    func sessions(in range: Range<Date>) -> [ListeningSession] {
        let lower = range.lowerBound
        let upper = range.upperBound
        let descriptor = FetchDescriptor<ListeningSession>(
            predicate: #Predicate { $0.startedAt >= lower && $0.startedAt < upper },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func recent(limit: Int = 30) -> [ListeningSession] {
        var descriptor = FetchDescriptor<ListeningSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 프리셋 자동 선택이 같은 채널만 고르지 않게 쓰는 값이다. M4 의 재정렬도 이걸 읽는다.
    func totalSeconds(itemID: String) -> TimeInterval {
        let descriptor = FetchDescriptor<ListeningSession>(
            predicate: #Predicate { $0.itemID == itemID }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.reduce(0) { $0 + $1.duration }
    }

    /// 추천 재정렬이 읽는 값. 세션을 한 번만 훑어 방송국별로 접는다.
    ///
    /// 기록 전체를 다 보지 않고 최근 것만 본다. 반년 전에 한 번 들은 방송국이
    /// 오늘 순서를 바꾸는 것은 개인화가 아니라 잡음이다.
    func profiles(situation: Situation?, since: Date? = nil, limit: Int = 800) -> [String: ListeningProfile] {
        let floor = since ?? Date().addingTimeInterval(-90 * 24 * 60 * 60)
        var descriptor = FetchDescriptor<ListeningSession>(
            predicate: #Predicate { $0.startedAt >= floor },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        var profiles: [String: ListeningProfile] = [:]
        for session in (try? context.fetch(descriptor)) ?? [] {
            var profile = profiles[session.itemID] ?? ListeningProfile()
            profile.totalSeconds += session.duration
            if session.skippedEarly { profile.earlySkips += 1 }
            if let situation, session.situationRaw == situation.rawValue { profile.playsInSituation += 1 }
            if profile.lastPlayedAt == nil || session.startedAt > profile.lastPlayedAt! {
                profile.lastPlayedAt = session.startedAt
            }
            profiles[session.itemID] = profile
        }
        return profiles
    }

    /// 추천 품질 지표 두 가지. `docs/04-curation.md` 6번과 같다. 기기 밖으로 나가지 않는다.
    func recommendationQuality(since: Date) -> (throughRecommendation: Double, earlySkipRate: Double, total: Int) {
        let sessions = self.sessions(in: since..<Date().addingTimeInterval(60))
        guard !sessions.isEmpty else { return (0, 0, 0) }
        let fromRecommendation = sessions.filter(\.fromRecommendation)
        let skipped = fromRecommendation.filter(\.skippedEarly).count
        return (
            Double(fromRecommendation.count) / Double(sessions.count),
            fromRecommendation.isEmpty ? 0 : Double(skipped) / Double(fromRecommendation.count),
            sessions.count
        )
    }

    func eraseAll() {
        do {
            try context.delete(model: ListeningSession.self)
            try context.save()
        } catch {
            log.error("청취 기록을 지우지 못했다: \(String(describing: error), privacy: .private)")
        }
    }
}
