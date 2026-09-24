import SwiftData
import SwiftUI

/// 프록시가 내려주는 방송국 목록. 스트림 주소는 여기에 오지 않는다.
struct DiscoverView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(HiddenAccess.self) private var hidden
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Favorite.addedAt, order: .reverse) private var favorites: [Favorite]

    @State private var model = DiscoverModel()
    @State private var store: StationStore?
    @State private var showFavoritesOnly = false
    @State private var mode: Mode = DiscoverView.initialMode

    /// 탐색 탭이 두 가지를 담는다. 탭은 다섯 개로 고정이라(`docs/01-features.md` 1번)
    /// 팟캐스트를 여섯 번째 탭으로 두지 않고 여기에 넣는다.
    enum Mode: String, CaseIterable, Identifiable {
        case stations, podcasts, hidden
        var id: String { rawValue }
        var label: String {
            switch self {
            case .stations: return "라디오"
            case .podcasts: return "팟캐스트"
            case .hidden: return "지상파"
            }
        }
    }

    /// 시뮬레이터에서 팟캐스트 쪽을 바로 열어 보려고 둔 통로다.
    /// `-ZPDiscoverMode podcasts` 또는 `hidden` 으로 켠다. 릴리스 빌드에서는 항상 라디오다.
    private static var initialMode: Mode {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "ZPDiscoverMode") {
        case "podcasts": return .podcasts
        case "hidden": return .hidden
        default: return .stations
        }
        #else
        .stations
        #endif
    }

    /// '지상파' 는 해제한 뒤에만 나온다. 해제 전에는 이 탭에 흔적이 없다.
    private var visibleModes: [Mode] {
        hidden.isUnlocked ? Mode.allCases : [.stations, .podcasts]
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .stations: stationList
                case .podcasts: PodcastListContent()
                case .hidden: HiddenRadioContent()
                }
            }
            .navigationTitle("탐색")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { modePicker }
            .onChange(of: hidden.isUnlocked) { _, unlocked in
                if !unlocked, mode == .hidden { mode = .stations }
            }
        }
    }

    private var modePicker: some View {
        Picker("무엇을 찾을지", selection: $mode) {
            ForEach(visibleModes) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var stationList: some View {
            List {
                if model.fromCache {
                    Label("네트워크에 닿지 못해 저장해 둔 목록을 보여줍니다. 재생은 연결된 뒤에 됩니다.",
                          systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if showFavoritesOnly {
                    if favorites.isEmpty {
                        ContentUnavailableView(
                            "즐겨찾기가 없습니다",
                            systemImage: "heart",
                            description: Text("목록을 왼쪽으로 밀거나 재생 화면의 하트를 눌러 담습니다.")
                        )
                    } else {
                        ForEach(favorites) { favorite in
                            Button {
                                Task { await player.play(favorite.playable) }
                            } label: {
                                favoriteRow(for: favorite)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("빼기", systemImage: "heart.slash", role: .destructive) {
                                    FavoriteStore(context: modelContext).toggle(favorite.playable)
                                }
                            }
                        }
                    }
                } else if let errorText = model.errorText {
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
                        .swipeActions(edge: .trailing) {
                            let isOn = isFavorite(station.id)
                            Button(isOn ? "빼기" : "즐겨찾기", systemImage: isOn ? "heart.slash" : "heart") {
                                FavoriteStore(context: modelContext).toggle(station.playable)
                            }
                            .tint(isOn ? .gray : .pink)
                        }
                        .task { await loadMore(after: station) }
                    }

                    if model.isLoadingMore {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $model.search, prompt: "방송국 이름")
            .onSubmit(of: .search) { Task { await refresh() } }
            .refreshable { await refresh() }
            .overlay { if model.isLoading && model.items.isEmpty { ProgressView() } }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !showFavoritesOnly { filterBar }
            }
            .toolbar {
                countryMenu
                favoritesToggle
            }
            .task { await start() }
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

    private var favoritesToggle: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showFavoritesOnly.toggle()
            } label: {
                Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
            }
            .accessibilityLabel(showFavoritesOnly ? "전체 목록 보기" : "즐겨찾기만 보기")
        }
    }

    private func favoriteRow(for favorite: Favorite) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if let subtitle = favorite.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if player.current?.id == favorite.itemID {
                Image(systemName: player.state == .playing ? "speaker.wave.2.fill" : "pause.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private func isFavorite(_ id: String) -> Bool {
        favorites.contains { $0.itemID == id }
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
            if isFavorite(station.id) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.pink)
            }
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
