import Foundation
import Observation
import os

/// 추천 탭이 보고 있는 상태.
///
/// 3단 구조의 마지막이 여기다(`docs/04-curation.md`). 서버가 1·2단을 끝낸 목록을 받아
/// 기기에 쌓인 청취 기록으로 다시 세우고, 기기 모델이 있으면 맨 위 한 줄만 다듬는다.
/// 세 단계가 각각 독립이라 서버 LLM 이 쉬어도, 기기 모델이 없어도 목록은 나온다.
@MainActor
@Observable
final class RecommendModel {
    struct Entry: Identifiable, Sendable {
        var item: RecommendationDTO
        /// 서버가 쓴 문구, 또는 기기 모델이 다듬은 문구.
        var reason: String?
        /// 내 기록 때문에 서버 순서보다 올라왔는지.
        var movedUp: Bool
        var id: String { item.id }
    }

    var situation: Situation = RecommendModel.situationForNow()
    private(set) var entries: [Entry] = []
    private(set) var isLoading = false
    private(set) var errorText: String?
    /// 서버가 무엇으로 만든 목록인지. 'llm' 이면 밤에 만들어 둔 세트다.
    private(set) var source: String?
    private(set) var usedOnDeviceModel = false

    private let client: ProxyClienting
    private let personalizer = Personalizer()
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "recommend")

    init(client: ProxyClienting = ProxyClient()) {
        self.client = client
    }

    /// 시계를 보고 첫 화면의 상황을 고른다. 사용자가 바꾸면 그 선택을 따른다.
    static func situationForNow(_ date: Date = .now) -> Situation {
        switch Calendar.current.component(.hour, from: date) {
        case 6..<9: return .wake
        case 9..<12: return .work
        case 12..<18: return .study
        case 18..<22: return .work
        default: return .sleep
        }
    }

    /// 자동 종료 기본값. 설정에서 고른 값이고, 서버가 이 길이에 맞는 에피소드를 섞어 준다.
    var timerMinutes: Int = UserDefaults.standard.integer(forKey: "zp.timer.defaultMinutes")

    func load(listening: ListeningStore, reasoner: OnDeviceReasoning) async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        let query = RecommendQuery(
            situation: situation,
            country: Locale.current.region?.identifier,
            at: .now,
            limit: 20,
            // 앱이 고른 것을 그대로 트는 자리라 열리는 스트림만 받는다(`CONTEXT.md` 6번).
            secureOnly: true,
            timerMinutes: timerMinutes
        )

        let set: RecommendationSetDTO
        do {
            set = try await client.recommendations(query)
        } catch {
            entries = []
            source = nil
            errorText = (error as? ProxyError)?.errorDescription ?? "추천을 가져오지 못했습니다."
            return
        }

        source = set.source
        let profiles = listening.profiles(situation: situation)
        let ranked = personalizer.rank(set.items, profiles: profiles)
        entries = ranked.map { Entry(item: $0.item, reason: $0.item.reason, movedUp: $0.movedUp > 0) }
        log.info("추천 \(set.items.count)개 (\(set.source, privacy: .public)/\(set.daypart, privacy: .public)) 재정렬 완료")

        await addPersonalNote(reasoner: reasoner, listening: listening)
    }

    /// 맨 위 한 건에만 기기 모델을 쓴다. 목록 전체에 쓰면 화면이 뜨는 데 시간이 걸린다.
    private func addPersonalNote(reasoner: OnDeviceReasoning, listening: ListeningStore) async {
        usedOnDeviceModel = false
        guard reasoner.availability.isReady, let first = entries.first else { return }

        let favourites = listening.recent(limit: 12).map(\.title)
        guard let note = await reasoner.personalNote(
            for: first.item,
            situation: situation,
            history: Array(Set(favourites)).sorted()
        ) else { return }

        guard entries.first?.id == first.id else { return }
        entries[0].reason = note
        usedOnDeviceModel = true
        log.info("기기 모델이 첫 항목 문구를 다듬었다")
    }

    /// 상황을 바꾸면 목록을 다시 받는다.
    func select(_ next: Situation, listening: ListeningStore, reasoner: OnDeviceReasoning) async {
        guard next != situation else { return }
        situation = next
        entries = []
        await load(listening: listening, reasoner: reasoner)
    }
}
