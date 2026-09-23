import SwiftUI

/// M1 확인용 화면이다. M2 에서 프록시가 내려주는 방송국 목록과 검색으로 바꾼다.
struct DiscoverView: View {
    @Environment(AudioPlayerService.self) private var player

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DemoStations.all, id: \.item.id) { entry in
                        Button {
                            Task { await player.play(entry.item) }
                        } label: {
                            row(for: entry.item)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("M1 에서 재생 경로를 확인하려고 손으로 적어둔 목록이다. M2 에서 프록시 목록으로 바꾼다.")
                }
            }
            .navigationTitle("탐색")
        }
    }

    private func row(for item: PlayableItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if player.current?.id == item.id {
                Image(systemName: player.state == .playing ? "speaker.wave.2.fill" : "pause.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    DiscoverView()
        .environment(AudioPlayerService())
}
