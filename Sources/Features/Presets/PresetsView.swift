import SwiftData
import SwiftUI

/// 상황 프리셋 목록. 카드를 누르면 바로 재생되고 타이머가 걸린다.
struct PresetsView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Preset.order) private var presets: [Preset]

    @State private var editing: Preset?
    @State private var isCreating = false
    @State private var startingID: UUID?
    @State private var errorText: String?
    @State private var startedTitle: String?

    var body: some View {
        NavigationStack {
            List {
                if let startedTitle {
                    Section {
                        Label(startedTitle, systemImage: "speaker.wave.2.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(presets) { preset in
                        row(for: preset)
                    }
                    .onDelete(perform: delete)
                    .onMove(perform: move)
                } footer: {
                    Text("카드를 누르면 바로 재생되고, 타이머가 걸려 있으면 그 시간이 지날 때 페이드아웃으로 꺼집니다.")
                }
            }
            .navigationTitle("프리셋")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("프리셋 추가")
                }
            }
            .sheet(item: $editing) { preset in
                PresetEditorView(preset: preset)
            }
            .sheet(isPresented: $isCreating) {
                PresetEditorView(preset: nil, order: presets.count)
            }
            .alert("재생하지 못했습니다", isPresented: .init(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("확인") { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
            .task { seedIfNeeded() }
        }
    }

    // MARK: - 조각

    private func row(for preset: Preset) -> some View {
        HStack(spacing: 14) {
            Image(systemName: preset.symbolName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if startingID == preset.presetID {
                        RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(.body.weight(.semibold))
                Text(preset.sourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let timer = preset.timerDescription {
                Label(timer, systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }

            Button { editing = preset } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(preset.name) 편집")
        }
        .contentShape(Rectangle())
        .onTapGesture { Task { await start(preset) } }
    }

    // MARK: - 동작

    private func start(_ preset: Preset) async {
        startingID = preset.presetID
        defer { startingID = nil }

        let launcher = PresetLauncher(
            player: player,
            fallback: { FavoriteStore(context: modelContext).all().map(\.playable) },
            profiles: { ListeningStore(context: modelContext).profiles(situation: $0) }
        )
        do {
            let item = try await launcher.start(preset)
            startedTitle = "\(preset.name) · \(item.title)"
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "재생하지 못했습니다."
        }
    }

    private func seedIfNeeded() {
        guard presets.isEmpty else { return }
        for preset in Preset.defaults() { modelContext.insert(preset) }
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(presets[index]) }
        renumber()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = presets
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, preset) in ordered.enumerated() { preset.order = index }
        try? modelContext.save()
    }

    private func renumber() {
        for (index, preset) in presets.enumerated() { preset.order = index }
        try? modelContext.save()
    }
}

#Preview {
    PresetsView()
        .environment(AudioPlayerService())
        .modelContainer(for: [Preset.self, Favorite.self], inMemory: true)
}
