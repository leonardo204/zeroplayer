import SwiftData
import SwiftUI

/// 청취 기록과 월간 리포트. 전부 기기 안의 값이다.
struct StatsView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ListeningSession.startedAt, order: .reverse) private var sessions: [ListeningSession]

    @State private var month = Date()

    private var calendar: Calendar { .current }

    private var report: MonthlyReport {
        let range = calendar.monthRange(for: month)
        let picked = sessions.filter { $0.startedAt >= range.lowerBound && $0.startedAt < range.upperBound }
        return MonthlyReport.make(from: picked, month: month)
    }

    var body: some View {
        NavigationStack {
            List {
                monthSection

                if report.isEmpty {
                    Section {
                        Text("이 달에는 들은 기록이 없습니다. 프리셋이나 탐색 탭에서 방송을 켜면 여기에 쌓입니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    topSection
                    presetSection
                    qualitySection
                }

                recentSection
            }
            .navigationTitle("기록")
            .safeAreaInset(edge: .bottom, spacing: 0) { AdBannerSlot(slot: .statsList) }
        }
    }

    // MARK: - 조각

    private var monthSection: some View {
        Section {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("지난달")
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(isCurrentMonth)
                    .accessibilityLabel("다음달")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(report.totalText)
                    .font(.largeTitle.weight(.semibold))
                Text(report.summaryLine(calendar: calendar))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var topSection: some View {
        Section("많이 들은 것") {
            ForEach(report.items.prefix(5)) { entry in
                HStack {
                    Text(entry.title).lineLimit(1)
                    Spacer()
                    Text(durationText(entry.seconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var presetSection: some View {
        if !report.presets.isEmpty {
            Section("프리셋") {
                ForEach(report.presets.prefix(5)) { entry in
                    HStack {
                        Text(entry.title)
                        Spacer()
                        Text("\(entry.count)번")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var qualitySection: some View {
        Section {
            HStack {
                Text("30초 안에 넘긴 비율")
                Spacer()
                Text(percentText(report.earlySkipRate))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("추천·프리셋에서 시작한 비율")
                Spacer()
                Text(percentText(report.recommendationShare))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("추천 품질")
        } footer: {
            Text("두 값은 기기 안에만 남습니다. 서버로 보내지 않습니다.")
        }
    }

    private var recentSection: some View {
        Section("최근 재생") {
            if sessions.isEmpty {
                Text("아직 없습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(sessions.prefix(20)) { session in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(session.title).lineLimit(1)
                        Spacer()
                        Text(durationText(session.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        if let preset = session.presetName {
                            Text("· \(preset)")
                        }
                        if session.skippedEarly {
                            Text("· 30초 안에 넘김")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 값 만들기

    private var monthTitle: String {
        month.formatted(.dateTime.year().month(.wide))
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func shift(_ months: Int) {
        guard let moved = calendar.date(byAdding: .month, value: months, to: month) else { return }
        month = moved
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return String(localized: "\(hours)시간 \(minutes)분") }
        if minutes > 0 { return String(localized: "\(minutes)분") }
        return String(localized: "\(total)초")
    }

    private func percentText(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}

#Preview {
    StatsView()
        .environment(AudioPlayerService())
        .modelContainer(for: [ListeningSession.self], inMemory: true)
}
