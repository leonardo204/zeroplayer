import Foundation

/// 한 방송국에 대해 내 기록이 말해 주는 것. 재정렬은 이 값만 본다.
struct ListeningProfile: Sendable {
    /// 그 방송국을 들은 시간 전부.
    var totalSeconds: TimeInterval = 0
    /// 지금 상황에서 들었던 횟수.
    var playsInSituation: Int = 0
    /// 30초 안에 넘긴 횟수.
    var earlySkips: Int = 0
    /// 마지막으로 들은 시각.
    var lastPlayedAt: Date?
}

/// 서버가 보낸 순서를 내 청취 기록으로 다시 세운다.
///
/// `docs/04-curation.md` 5.2 의 점수식을 그대로 쓴다. 가중치는 출발값이라
/// 실제로 써 보며 조정한다. 마지막 항이 없으면 매일 같은 방송국만 위에 뜬다.
///
/// 기록은 전부 기기 안에만 있다. 이 계산도 기기에서 끝난다.
struct Personalizer: Sendable {
    var totalWeight: Double = 0.8
    var situationWeight: Double = 0.5
    var skipPenalty: Double = 1.2
    var recentPenalty: Double = 0.3
    /// 이 기간 안에 들었으면 순위를 조금 내린다.
    var recentWindow: TimeInterval = 3 * 24 * 60 * 60

    struct Scored: Sendable {
        var item: RecommendationDTO
        var score: Double
        var serverRank: Int
        /// 서버 순서에서 몇 칸 올라갔는지. 양수면 올라간 것이다.
        var movedUp: Int
    }

    func rank(
        _ items: [RecommendationDTO],
        profiles: [String: ListeningProfile],
        now: Date = .now
    ) -> [Scored] {
        let count = items.count
        let scored = items.enumerated().map { index, item -> (Int, Double, RecommendationDTO) in
            let profile = profiles[item.id] ?? ListeningProfile()
            var score = Double(count - index)
            score += totalWeight * log(profile.totalSeconds + 1)
            score += situationWeight * Double(profile.playsInSituation)
            score -= skipPenalty * Double(profile.earlySkips)
            if let last = profile.lastPlayedAt, now.timeIntervalSince(last) < recentWindow {
                score -= recentPenalty
            }
            return (index, score, item)
        }

        // 점수가 같으면 서버 순서를 지킨다. 같은 목록을 두 번 불러도 순서가 흔들리지 않는다.
        let ordered = scored.sorted { left, right in
            left.1 == right.1 ? left.0 < right.0 : left.1 > right.1
        }

        return ordered.enumerated().map { newIndex, entry in
            Scored(item: entry.2, score: entry.1, serverRank: entry.0, movedUp: entry.0 - newIndex)
        }
    }
}
