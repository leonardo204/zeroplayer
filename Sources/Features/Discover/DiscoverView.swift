import SwiftData
import SwiftUI

/// 프록시가 내려주는 방송국 목록. 스트림 주소는 여기에 오지 않는다.
struct DiscoverView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.modelContext) private var modelContext

    @State private var model = DiscoverModel()
    @State private var store: StationStore?

    var body: some View {
        NavigationStack {
            List {
                if model.fromCache {
                    Label("네트워크에 닿지 못해 저장해 둔 목록을 보여줍니다. 재생은 연결된 뒤에 됩니다.",
                          systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorText = model.errorText {
                    ContentUnavailableView {
                        Label("목록을 가져오지 못했습니다", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorText)
                    } actions: {
                        Button("다시 시도") { Task { await refresh() } }
                    }
                } else if model.items.isEmpty && !model.isLoading {
                    ContentUnavailableView.search
                } else {
                    ForEach(model.items, id: \.id) { station in
                        Button {
                            Task { await player.play(station.playable) }
                        } label: {
                            row(for: station)
                        }
                        .buttonStyle(.plain)
                        .task { await loadMore(after: station) }
                    }

                    if model.isLoadingMore {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("탐색")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $model.search, prompt: "방송국 이름")
            .onSubmit(of: .search) { Task { await refresh() } }
            .refreshable { await refresh() }
            .overlay { if model.isLoading && model.items.isEmpty { ProgressView() } }
            .safeAreaInset(edge: .top, spacing: 0) { filterBar }
            .toolbar { countryMenu }
            .task { await start() }
        }
    }

    // MARK: - 조각

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: "전체", isOn: model.tag == nil) {
                    model.tag = nil
                    Task { await refresh() }
                }
                ForEach(model.facets?.tags.prefix(24) ?? [], id: \.value) { facet in
                    chip(title: facet.value, isOn: model.tag == facet.value) {
                        model.tag = model.tag == facet.value ? nil : facet.value
                        Task { await refresh() }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: Capsule())
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
    }

    private var countryMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("전체 나라") {
                    model.country = nil
                    Task { await refresh() }
                }
                ForEach(model.facets?.countries.prefix(30) ?? [], id: \.value) { facet in
                    Button("\(facet.value) (\(facet.count))") {
                        model.country = facet.value
                        Task { await refresh() }
                    }
                }
            } label: {
                Label(model.country ?? "전체", systemImage: "globe")
            }
        }
    }

    private func row(for station: StationDTO) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if let subtitle = station.playable.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if player.current?.id == station.id {
                Image(systemName: player.state == .playing ? "speaker.wave.2.fill" : "pause.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - 동작

    private func start() async {
        if store == nil { store = StationStore(context: modelContext) }
        guard let store else { return }
        await model.loadFacetsIfNeeded(using: store)
        if model.items.isEmpty { await model.refresh(using: store) }
    }

    private func refresh() async {
        guard let store else { return }
        await model.refresh(using: store)
    }

    private func loadMore(after station: StationDTO) async {
        guard let store else { return }
        await model.loadMoreIfNeeded(current: station, using: store)
    }
}
