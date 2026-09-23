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
                if let subtitle = player.current?.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            controls

            Spacer()
        }
        .presentationDragIndicator(.visible)
    }

    private var controls: some View {
        HStack(spacing: 40) {
            Button { Task { await player.previous() } } label: {
                Image(systemName: "backward.fill").font(.title2)
            }
            .accessibilityLabel("이전")

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
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlayerView()
        .environment(AudioPlayerService())
}
