import Foundation

/// 한 달치 청취 기록을 요약한 값. 계산만 하므로 화면과 떼어 두고 테스트할 수 있다.
struct MonthlyReport: Equatable {
    struct Entry: Equatable, Identifiable {
        var id: String { key }
        let key: String
        let title: String
        let seconds: TimeInterval
        let count: Int
    }

    let month: Date
    let totalSeconds: TimeInterval
    let sessionCount: Int
    let items: [Entry]
    let presets: [Entry]
    /// 30초 안에 끝난 비율. 추천 품질 지표다.
    let earlySkipRate: Double
    /// 추천이나 프리셋 자동 선택에서 시작한 비율.
    let recommendationShare: Double

    var isEmpty: Bool { sessionCount == 0 }

    var totalText: String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        if hours > 0 { return "\(hours)시간 \(minutes)분" }
        return "\(minutes)분"
    }

    static func make(from sessions: [ListeningSession], month: Date) -> MonthlyReport {
        let total = sessions.reduce(0) { $0 + $1.duration }

        var byItem: [String: Entry] = [:]
        for session in sessions {
            let previous = byItem[session.itemID]
            byItem[session.itemID] = Entry(
                key: session.itemID,
                title: session.title,
                seconds: (previous?.seconds ?? 0) + session.duration,
                count: (previous?.count ?? 0) + 1
            )
        }

        var byPreset: [String: Entry] = [:]
        for session in sessions {
            guard let name = session.presetName else { continue }
            let previous = byPreset[name]
            byPreset[name] = Entry(
                key: name,
                title: name,
                seconds: (previous?.seconds ?? 0) + session.duration,
                count: (previous?.count ?? 0) + 1
            )
        }

        let skipped = sessions.filter(\.skippedEarly).count
        let recommended = sessions.filter(\.fromRecommendation).count
        let denominator = Double(max(sessions.count, 1))

        return MonthlyReport(
            month: month,
            totalSeconds: total,
            sessionCount: sessions.count,
            items: byItem.values.sorted { $0.seconds > $1.seconds },
            presets: byPreset.values.sorted { $0.count > $1.count },
            earlySkipRate: sessions.isEmpty ? 0 : Double(skipped) / denominator,
            recommendationShare: sessions.isEmpty ? 0 : Double(recommended) / denominator
        )
    }

    /// "9월에 152시간. 가장 많이 들은 것은 Jazz24. 취침 프리셋을 24일 썼다." 형태의 한 줄.
    func summaryLine(calendar: Calendar = .current) -> String {
        guard !isEmpty else { return "이 달에는 기록이 없습니다." }
        var parts = ["\(calendar.component(.month, from: month))월에 \(totalText)를 들었습니다."]
        if let top = items.first {
            parts.append("가장 많이 들은 것은 \(top.title) 입니다.")
        }
        if let preset = presets.first {
            parts.append("\(preset.title) 프리셋을 \(preset.count)번 썼습니다.")
        }
        return parts.joined(separator: " ")
    }
}

extension Calendar {
    /// 그 달의 시작과 다음 달의 시작.
    func monthRange(for date: Date) -> Range<Date> {
        let start = self.date(from: dateComponents([.year, .month], from: date)) ?? date
        let end = self.date(byAdding: .month, value: 1, to: start) ?? date
        return start..<end
    }
}
