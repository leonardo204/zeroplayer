import SwiftUI

struct PlayerView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary)
                .frame(width: 260, height: 260)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                }

            VStack(spacing: 6) {
                Text(player.current?.title ?? "재생 중인 항목이 없습니다")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let streamTitle = player.streamTitle {
                    Text(streamTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if let subtitle = player.current?.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                statusLine
            }
            .padding(.horizontal)

            controls

            if player.current != nil {
                Button("정지", role: .destructive) { player.stop() }
                    .buttonStyle(.bordered)
            }

            Spacer()
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch player.state {
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                Text("연결 중…")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        case .failed(let reason):
            Text(reason.message)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(.top, 4)
        case .playing, .paused:
            Text(Self.formatElapsed(player.elapsed))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var controls: some View {
        if case .failed = player.state {
            Button {
                Task { await player.retry() }
            } label: {
                Label("다시 시도", systemImage: "arrow.clockwise")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
        } else {
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
                .disabled(player.state == .loading)

                Button { Task { await player.next() } } label: {
                    Image(systemName: "forward.fill").font(.title2)
                }
                .accessibilityLabel("다음")
                .disabled(true)
            }
            .buttonStyle(.plain)
        }
    }

    static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

#Preview {
    PlayerView()
        .environment(AudioPlayerService())
}
