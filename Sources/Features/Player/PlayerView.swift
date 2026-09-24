import SwiftData
import SwiftUI

struct PlayerView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var favorites: [Favorite]
    @State private var isTimerPresented = false

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
        RoundedRectangle(cornerRadius: 16)
            .fill(.quaternary)
            .frame(width: 240, height: 240)
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
            }
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
            Text(elapsedText)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        case .idle:
            EmptyView()
        }
    }

    private var elapsedText: String {
        let total = Int(player.elapsed)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d 재생 중", minutes, seconds)
    }

    private var controls: some View {
        HStack(spacing: 40) {
            Button { Task { await player.previous() } } label: {
                Image(systemName: "backward.fill").font(.title2)
            }
            .accessibilityLabel("이전")
            .disabled(true)

            Button {
                if player.state == .playing { player.pause() } else { player.resume() }
            } label: {
                Image(systemName: player.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .accessibilityLabel(player.state == .playing ? "일시정지" : "재생")

            Button { Task { await player.next() } } label: {
                Image(systemName: "forward.fill").font(.title2)
            }
            .accessibilityLabel("다음")
            .disabled(true)
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
