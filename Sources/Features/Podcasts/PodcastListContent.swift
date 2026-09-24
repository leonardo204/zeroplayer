import SwiftData
import SwiftUI

/// 탐색 탭의 팟캐스트 쪽. 바깥의 `NavigationStack` 안에 들어간다.
struct PodcastListContent: View {
    @Environment(\.modelContext) private var modelContext
    @State private var model = PodcastModel()
    @State private var resumable: [PlaybackPosition] = []

    var body: some View {
        List {
            if !resumable.isEmpty && model.search.isEmpty {
                Section("이어듣기") {
                    ForEach(resumable, id: \.itemID) { position in
                        NavigationLink(value: ResumeTarget(position: position)) {
                            resumeRow(position)
                        }
                    }
                }
            }

            if let errorText = model.errorText {
                ContentUnavailableView {
                    Label("팟캐스트를 가져오지 못했습니다", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorText)
                } actions: {
                    Button("다시 시도") { Task { await model.load() } }
                }
            } else if model.items.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    "팟캐스트가 없습니다",
                    systemImage: "mic",
                    description: Text(model.search.isEmpty
                                      ? String(localized: "서버가 인기 목록을 받아 두면 여기에 나옵니다.")
                                      : String(localized: "다른 말로 찾아 보세요."))
                )
            } else {
                Section(model.search.isEmpty ? "인기" : "검색 결과") {
                    ForEach(model.items) { podcast in
                        NavigationLink(value: podcast) {
                            row(podcast)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $model.search, prompt: "팟캐스트 이름")
        .onSubmit(of: .search) { Task { await model.load() } }
        .refreshable { await reload() }
        .overlay { if model.isLoading && model.items.isEmpty { ProgressView() } }
        .navigationDestination(for: PodcastDTO.self) { podcast in
            PodcastDetailView(podcast: podcast)
        }
        .navigationDestination(for: ResumeTarget.self) { target in
            PodcastDetailView(feedID: target.feedID, title: target.title)
        }
        .task { await reload() }
    }

    private func reload() async {
        resumable = PositionStore(context: modelContext).recent(limit: 5)
        await model.load()
    }

    private func row(_ podcast: PodcastDTO) -> some View {
        HStack(spacing: 12) {
            PodcastArtwork(url: podcast.artworkURL, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(podcast.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if let subtitle = podcast.subtitleText {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func resumeRow(_ position: PlaybackPosition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(position.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            ProgressView(value: position.fraction)
                .tint(.accentColor)
            HStack {
                if let podcastTitle = position.podcastTitle {
                    Text(podcastTitle).lineLimit(1)
                }
                Spacer()
                if let remaining = position.remainingText {
                    Text(remaining)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

/// 이어듣기 줄을 눌렀을 때 넘길 값. 그 에피소드가 속한 팟캐스트를 연다.
struct ResumeTarget: Hashable {
    let feedID: String
    let title: String

    init(position: PlaybackPosition) {
        // feedID 가 없으면 에피소드 ID 앞부분이 피드 ID 다('it:123:abc').
        self.feedID = position.feedID ?? position.itemID.split(separator: ":").prefix(2).joined(separator: ":")
        self.title = position.podcastTitle ?? position.title
    }
}

/// 앨범아트. 주소가 없거나 못 받으면 같은 크기 자리만 둔다.
struct PodcastArtwork: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size / 8)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "mic")
                            .font(.system(size: size / 3))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size / 8))
    }
}
