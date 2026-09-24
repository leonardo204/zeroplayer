import SwiftData
import SwiftUI

/// 상황을 고르면 지금 틀 만한 방송을 순서대로 보여 준다.
struct RecommendView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(OnDeviceReasoner.self) private var reasoner
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]

    @State private var model = RecommendModel()
    @State private var listening: ListeningStore?

    var body: some View {
        NavigationStack {
            List {
                if let errorText = model.errorText {
                    ContentUnavailableView {
                        Label("추천을 가져오지 못했습니다", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorText)
                    } actions: {
                        Button("다시 시도") { Task { await load() } }
                    }
                } else if model.entries.isEmpty && !model.isLoading {
                    ContentUnavailableView(
                        "지금 조건에 맞는 방송이 없습니다",
                        systemImage: "sparkles",
                        description: Text("다른 상황을 골라 보세요.")
                    )
                } else {
                    ForEach(Array(model.entries.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            Task { await play(entry) }
                        } label: {
                            row(for: entry, rank: index + 1)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            let isOn = favorites.contains { $0.itemID == entry.id }
                            Button {
                                FavoriteStore(context: modelContext).toggle(entry.item.playable)
                            } label: {
                                Label(isOn ? "빼기" : "즐겨찾기", systemImage: isOn ? "heart.slash" : "heart")
                            }
                            .tint(isOn ? .gray : .pink)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("추천")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { situationBar }
            .refreshable { await load() }
            .overlay { if model.isLoading && model.entries.isEmpty { ProgressView() } }
            .task { await start() }
        }
    }

    // MARK: - 조각

    private var situationBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Situation.allCases, id: \.self) { situation in
                    let isOn = model.situation == situation
                    Button {
                        Task { await select(situation) }
                    } label: {
                        Label(situation.label, systemImage: situation.symbolName)
                            .font(.footnote.weight(isOn ? .semibold : .regular))
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: Capsule())
                            .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
    }

    private func row(for entry: RecommendModel.Entry, rank: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.item.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if entry.movedUp {
                        Image(systemName: "arrow.up")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tint)
                            .accessibilityLabel("내 기록 때문에 위로 올라온 항목")
                    }
                    if favorites.contains(where: { $0.itemID == entry.id }) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.pink)
                    }
                }

                if let reason = entry.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if !entry.item.tags.isEmpty {
                    Text(entry.item.tags.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if player.current?.id == entry.id {
                Image(systemName: player.state == .playing ? "speaker.wave.2.fill" : "pause.fill")
                    .foregroundStyle(.tint)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    // MARK: - 동작

    private func start() async {
        if listening == nil { listening = ListeningStore(context: modelContext) }
        if model.entries.isEmpty { await load() }
    }

    private func load() async {
        guard let listening else { return }
        await model.load(listening: listening, reasoner: reasoner)
    }

    private func select(_ situation: Situation) async {
        guard let listening else { return }
        await model.select(situation, listening: listening, reasoner: reasoner)
    }

    /// 추천에서 시작한 재생은 기록에 그렇게 남는다. 30초 이탈률이 추천 품질 지표가 된다.
    private func play(_ entry: RecommendModel.Entry) async {
        await player.play(
            entry.item.playable,
            origin: PlaybackOrigin(fromRecommendation: true, situation: model.situation)
        )
    }
}
