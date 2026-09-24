import SwiftData
import SwiftUI

/// 한 팟캐스트의 에피소드 목록. 누르면 바로 재생되고, 듣던 것은 이어서 시작한다.
struct PodcastDetailView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.modelContext) private var modelContext

    private let feedID: String
    private let fallbackTitle: String
    private let known: PodcastDTO?

    @State private var model = EpisodeListModel()
    @State private var positions: [String: PlaybackPosition] = [:]

    init(podcast: PodcastDTO) {
        self.feedID = podcast.feedID
        self.fallbackTitle = podcast.title
        self.known = podcast
    }

    init(feedID: String, title: String) {
        self.feedID = feedID
        self.fallbackTitle = title
        self.known = nil
    }

    private var podcast: PodcastDTO? { model.podcast ?? known }

    var body: some View {
        List {
            if let podcast {
                Section {
                    header(podcast)
                }
            }

            if let errorText = model.errorText {
                ContentUnavailableView {
                    Label("에피소드를 가져오지 못했습니다", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorText)
                }
            } else if !model.episodes.isEmpty {
                Section("에피소드") {
                    ForEach(model.episodes) { episode in
                        Button {
                            Task { await play(episode) }
                        } label: {
                            row(episode)
                        }
                        .buttonStyle(.plain)
                        .task { await model.loadMoreIfNeeded(current: episode, feedID: feedID) }
                    }
                    if model.isLoadingMore {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(podcast?.title ?? fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.isLoading { ProgressView() } }
        .task {
            await model.load(feedID: feedID)
            refreshPositions()
        }
    }

    // MARK: - 조각

    private func header(_ podcast: PodcastDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                PodcastArtwork(url: podcast.artworkURL, size: 88)
                VStack(alignment: .leading, spacing: 4) {
                    if let author = podcast.author {
                        Text(author).font(.subheadline.weight(.medium))
                    }
                    if !podcast.categories.isEmpty {
                        Text(podcast.categories.prefix(3).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if podcast.episodeCount > 0 {
                        Text("\(podcast.episodeCount)편")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let description = podcast.description {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 4)
    }

    private func row(_ episode: EpisodeDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            HStack(spacing: 8) {
                if let published = episode.publishedText { Text(published) }
                if let runtime = episode.runtimeText { Text(runtime) }
                if episode.isSecure == false {
                    Label("평문 HTTP", systemImage: "lock.open")
                        .foregroundStyle(.orange)
                }
                if player.current?.id == episode.id {
                    Label(player.state == .playing ? "재생 중" : "멈춤",
                          systemImage: player.state == .playing ? "speaker.wave.2.fill" : "pause.fill")
                        .foregroundStyle(.tint)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let position = positions[episode.id] {
                HStack(spacing: 6) {
                    ProgressView(value: position.fraction).tint(.accentColor)
                    if let remaining = position.remainingText {
                        Text(remaining).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - 동작

    private func play(_ episode: EpisodeDTO) async {
        await player.play(episode.playable, origin: .manual)
        refreshPositions()
    }

    private func refreshPositions() {
        let store = PositionStore(context: modelContext)
        var map: [String: PlaybackPosition] = [:]
        for row in store.recent(limit: 60) { map[row.itemID] = row }
        positions = map
    }
}
