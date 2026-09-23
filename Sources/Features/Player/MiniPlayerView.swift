import SwiftUI

struct MiniPlayerView: View {
    @Environment(AudioPlayerService.self) private var player
    var onTap: () -> Void

    var body: some View {
        if let item = player.current {
            HStack(spacing: 12) {
                artwork
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.streamTitle ?? item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(secondLine(for: item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                controlButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
            }
    }

    @ViewBuilder
    private var controlButton: some View {
        switch player.state {
        case .loading:
            ProgressView()
                .frame(width: 44, height: 44)
        case .failed:
            Button { Task { await player.retry() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("다시 시도")
        case .playing, .paused, .idle:
            Button(action: toggle) {
                Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.state == .playing ? "일시정지" : "재생")
        }
    }

    private func secondLine(for item: PlayableItem) -> String {
        switch player.state {
        case .loading:
            return "연결 중…"
        case .failed(let reason):
            return reason.message
        case .playing, .paused, .idle:
            if player.streamTitle != nil { return item.title }
            return item.subtitle ?? ""
        }
    }

    private func toggle() {
        if player.state == .playing {
            player.pause()
        } else {
            player.resume()
        }
    }
}
