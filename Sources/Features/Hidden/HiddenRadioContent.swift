import SwiftUI

/// 탐색 탭 안에 들어가는 한국 지상파 목록.
///
/// 여섯 번째 탭으로 두지 않는다 — iOS `TabView` 는 탭이 다섯 개를 넘으면 '더 보기' 로
/// 접어 버린다(`docs/01-features.md` 2.4). 해제 전에는 이 화면으로 가는 길 자체가 없다.
struct HiddenRadioContent: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(HiddenAccess.self) private var hidden

    @State private var model = HiddenModel()

    var body: some View {
        List {
            if let errorText = model.errorText {
                ContentUnavailableView {
                    Label("채널을 가져오지 못했습니다", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorText)
                } actions: {
                    Button("다시 시도") { Task { await load() } }
                }
            } else {
                ForEach(grouped, id: \.0) { broadcaster, items in
                    Section(broadcaster) {
                        ForEach(items) { channel in
                            Button {
                                Task { await play(channel) }
                            } label: {
                                row(for: channel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { if model.isLoading && model.channels.isEmpty { ProgressView() } }
        .refreshable { await load() }
        .task { if model.channels.isEmpty { await load() } }
    }

    /// 방송사별로 묶는다. 순서는 서버가 준 그대로 둔다.
    private var grouped: [(String, [HiddenChannelDTO])] {
        var order: [String] = []
        var bucket: [String: [HiddenChannelDTO]] = [:]
        for channel in model.channels {
            if bucket[channel.broadcaster] == nil { order.append(channel.broadcaster) }
            bucket[channel.broadcaster, default: []].append(channel)
        }
        return order.map { ($0, bucket[$0] ?? []) }
    }

    private func row(for channel: HiddenChannelDTO) -> some View {
        HStack(spacing: 12) {
            // 편성표가 주는 프로그램 그림이 있으면 그쪽이 낫다. 없으면 방송사 로고다.
            ArtworkView(
                url: (model.nowByChannel[channel.id]?.artworkURL ?? channel.artworkURL)
                    .flatMap(URL.init(string:)),
                title: channel.name,
                size: 44,
                cornerRadius: 8
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(channel.name)
                    .font(.body.weight(.medium))
                if let now = model.nowByChannel[channel.id], let program = now.programName {
                    Text(program)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let range = now.timeRange {
                        Text(range)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 8)
            if player.current?.id == channel.id {
                Image(systemName: player.state == .playing ? "speaker.wave.2.fill" : "pause.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private func load() async {
        guard let token = hidden.token else { return }
        await model.load(token: token)
    }

    private func play(_ channel: HiddenChannelDTO) async {
        var item = channel.playable
        // 재생 화면에 채널 이름만 덩그러니 두지 않게 지금 방송을 부제로 붙인다.
        if let program = model.nowByChannel[channel.id]?.programName {
            item.subtitle = program
        }
        await player.play(item)
        guard let token = hidden.token else { return }
        await model.refreshNow(channelID: channel.id, token: token)
    }
}
