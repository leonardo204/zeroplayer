import SwiftData
import SwiftUI

struct PlayerView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var favorites: [Favorite]
    @State private var isTimerPresented = false
    /// 진행 바를 끌고 있는 동안의 값. 손을 떼면 그 자리로 옮기고 비운다.
    @State private var scrub: Double?

    private var isEpisode: Bool { player.current?.kind == .podcast }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)

            artwork

            VStack(spacing: 6) {
                Text(player.streamTitle ?? player.current?.title ?? "재생 중인 항목이 없습니다")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let second = secondLine {
                    Text(second)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)

            statusLine

            controls

            sideButtons

            Spacer(minLength: 8)
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isTimerPresented) {
            SleepTimerSheet()
        }
    }

    // MARK: - 조각

    private var artwork: some View {
        ArtworkView(
            url: player.artworkURL,
            title: player.current?.title ?? "",
            size: 240,
            cornerRadius: 16,
            symbolName: isEpisode ? "mic" : "waveform"
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }

    private var secondLine: String? {
        guard let item = player.current else { return nil }
        if player.streamTitle != nil { return item.title }
        return item.subtitle
    }

    @ViewBuilder
    private var statusLine: some View {
        switch player.state {
        case .loading:
            Label("연결 중…", systemImage: "antenna.radiowaves.left.and.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .failed(let reason):
            VStack(spacing: 8) {
                Label(reason.message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("다시 시도") { Task { await player.retry() } }
                    .buttonStyle(.bordered)
            }
        case .playing, .paused:
            if isEpisode && player.duration > 0 {
                progressBar
            } else {
                Text(elapsedText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .idle:
            EmptyView()
        }
    }

    private var elapsedText: String {
        let total = Int(player.elapsed)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: String(localized: "%d:%02d 재생 중"), minutes, seconds)
    }

    private var progressBar: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { scrub ?? player.elapsed },
                    set: { scrub = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    guard !editing, let target = scrub else { return }
                    player.seek(to: target)
                    scrub = nil
                }
            )
            HStack {
                Text(timeText(scrub ?? player.elapsed))
                Spacer()
                Text("-" + timeText(max(0, player.duration - (scrub ?? player.elapsed))))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    private var controls: some View {
        HStack(spacing: 40) {
            if isEpisode {
                Button { player.skip(by: -AudioPlayerService.skipBackSeconds) } label: {
                    Image(systemName: "gobackward.15").font(.title2)
                }
                .accessibilityLabel("15초 되감기")
            } else {
                Button { Task { await player.previous() } } label: {
                    Image(systemName: "backward.fill").font(.title2)
                }
                .accessibilityLabel("이전")
                .disabled(true)
            }

            Button {
                if player.state == .playing {
                    player.pause()
                } else {
                    Task { await player.resume() }
                }
            } label: {
                Image(systemName: player.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .accessibilityLabel(player.state == .playing ? "일시정지" : "재생")

            if isEpisode {
                Button { player.skip(by: AudioPlayerService.skipForwardSeconds) } label: {
                    Image(systemName: "goforward.30").font(.title2)
                }
                .accessibilityLabel("30초 건너뛰기")
            } else {
                Button { Task { await player.next() } } label: {
                    Image(systemName: "forward.fill").font(.title2)
                }
                .accessibilityLabel("다음")
                .disabled(true)
            }
        }
        .buttonStyle(.plain)
    }

    private var sideButtons: some View {
        HStack(spacing: 28) {
            Button(action: toggleFavorite) {
                VStack(spacing: 4) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.title3)
                    Text("즐겨찾기").font(.caption2)
                }
            }
            .buttonStyle(.plain)
            .disabled(player.current == nil)
            .accessibilityLabel(isFavorite ? "즐겨찾기 해제" : "즐겨찾기 추가")

            if isEpisode {
                Menu {
                    ForEach(AudioPlayerService.rateChoices, id: \.self) { rate in
                        Button {
                            player.setRate(rate)
                        } label: {
                            if player.playbackRate == rate {
                                Label(rateText(rate), systemImage: "checkmark")
                            } else {
                                Text(rateText(rate))
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "speedometer").font(.title3)
                        Text(rateText(player.playbackRate)).font(.caption2.monospacedDigit())
                    }
                }
                .accessibilityLabel("재생 속도")
            }

            Button { isTimerPresented = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: player.sleepTimer.isRunning ? "timer.circle.fill" : "timer")
                        .font(.title3)
                    Text(player.sleepTimer.remainingText ?? "자동 종료")
                        .font(.caption2.monospacedDigit())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("자동 종료 타이머")

            Button {
                player.stop()
                dismiss()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill").font(.title3)
                    Text("정지").font(.caption2)
                }
            }
            .buttonStyle(.plain)
            .disabled(player.current == nil)
            .accessibilityLabel("정지")
        }
        .foregroundStyle(.secondary)
    }

    private func rateText(_ rate: Double) -> String {
        rate == 1.0 ? String(localized: "1배") : String(format: String(localized: "%.1f배"), rate)
    }

    // MARK: - 즐겨찾기

    private var isFavorite: Bool {
        guard let id = player.current?.id else { return false }
        return favorites.contains { $0.itemID == id }
    }

    private func toggleFavorite() {
        guard let item = player.current else { return }
        FavoriteStore(context: modelContext).toggle(item)
    }
}

#Preview {
    PlayerView()
        .environment(AudioPlayerService())
        .modelContainer(for: [Favorite.self], inMemory: true)
}
