import SwiftData
import SwiftUI

/// 프리셋에 걸 방송국 하나를 고른다. 목록은 탐색 탭과 같은 `StationStore` 를 쓴다.
struct StationPickerView: View {
    var onPick: (StationDTO) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var model = DiscoverModel()
    @State private var store: StationStore?

    var body: some View {
        NavigationStack {
            List {
                if model.items.isEmpty && !model.isLoading {
                    ContentUnavailableView.search
                }
                ForEach(model.items, id: \.id) { station in
                    Button {
                        onPick(station)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(station.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if let subtitle = station.playable.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .task { await loadMore(after: station) }
                }
            }
            .listStyle(.plain)
            .navigationTitle("방송국 고르기")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $model.search, prompt: "방송국 이름")
            .onSubmit(of: .search) { Task { await refresh() } }
            .overlay { if model.isLoading && model.items.isEmpty { ProgressView() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .task { await start() }
        }
    }

    private func start() async {
        if store == nil { store = StationStore(context: modelContext) }
        guard let store, model.items.isEmpty else { return }
        await model.refresh(using: store)
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
