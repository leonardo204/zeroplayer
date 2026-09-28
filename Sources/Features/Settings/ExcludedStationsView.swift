import SwiftData
import SwiftUI

/// '그만 듣기' 로 뺀 방송국 목록. 되돌리는 자리다.
///
/// 되돌릴 길이 보이지 않으면 사용자가 '그만 듣기' 를 아예 안 누른다. 그래서 전부
/// 비우는 단추 하나로 두지 않고, 뺀 것을 이름과 날짜와 함께 보여 주고 하나씩
/// 되돌릴 수 있게 한다. 실수로 하나 뺀 것을 되돌리는 것이 훨씬 흔한 일이다.
struct ExcludedStationsView: View {
    @Environment(ExcludedStore.self) private var excluded
    @Query(sort: \ExcludedStation.addedAt, order: .reverse)
    private var rows: [ExcludedStation]

    @State private var isRestoreAllPresented = false

    var body: some View {
        List {
            if rows.isEmpty {
                ContentUnavailableView(
                    "뺀 방송이 없습니다",
                    systemImage: "speaker.wave.2",
                    description: Text("""
                    재생 화면에서 '그만 듣기' 를 누르면 그 방송이 여기에 담기고, \
                    앱이 알아서 고를 때 건너뜁니다.
                    """)
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(rows) { row in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(row.addedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Button("되돌리기") { restore(row) }
                                .font(.footnote.weight(.semibold))
                                .buttonStyle(.bordered)
                        }
                    }
                    .onDelete(perform: delete)
                } footer: {
                    Text("""
                    뺀 방송은 추천 목록과 프리셋·알람의 자동 선택에서 건너뜁니다. \
                    탐색 탭에서는 그대로 찾을 수 있고, 눌러서 들을 수 있습니다.
                    """)
                }

                Section {
                    Button("모두 되돌리기", role: .destructive) {
                        isRestoreAllPresented = true
                    }
                }
            }
        }
        .navigationTitle("그만 듣는 방송")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !rows.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        .confirmationDialog(
            "뺀 방송을 모두 되돌립니다",
            isPresented: $isRestoreAllPresented,
            titleVisibility: .visible
        ) {
            Button("되돌리기") { excluded.restoreAll() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(rows.count)개가 다시 추천과 자동 선택에 들어옵니다.")
        }
    }

    private func restore(_ row: ExcludedStation) {
        excluded.restore(row)
    }

    private func delete(at offsets: IndexSet) {
        for row in offsets.map({ rows[$0] }) { excluded.restore(row) }
    }
}
