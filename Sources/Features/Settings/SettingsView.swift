import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(OnDeviceReasoner.self) private var reasoner
    @Query private var favorites: [Favorite]
    @Query private var sessions: [ListeningSession]

    @AppStorage("zp.timer.defaultMinutes") private var defaultMinutes = 45
    @AppStorage("zp.timer.fadeSeconds") private var fadeSeconds = 30

    @State private var isEraseConfirmPresented = false

    /// 추천 품질 지표. 기록이 바뀔 때만 다시 센다.
    private var quality: (throughRecommendation: Double, earlySkipRate: Double, total: Int) {
        ListeningStore(context: modelContext)
            .recommendationQuality(since: Date().addingTimeInterval(-30 * 24 * 60 * 60))
    }

    private func percent(_ value: Double) -> String {
        quality.total == 0 ? "기록 없음" : "\(Int((value * 100).rounded()))%"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("자동 종료 기본값") {
                    Picker("타이머", selection: $defaultMinutes) {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { minutes in
                            Text("\(minutes)분").tag(minutes)
                        }
                    }
                    Picker("페이드아웃", selection: $fadeSeconds) {
                        ForEach([0, 10, 30, 60], id: \.self) { seconds in
                            Text(seconds == 0 ? "없음" : "\(seconds)초").tag(seconds)
                        }
                    }
                }

                Section {
                    LabeledContent("기기 안 모델") {
                        Text(reasoner.availability.isReady ? "사용 중" : "쓰지 않음")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("추천")
                } footer: {
                    Text(reasoner.availability.message)
                }

                Section {
                    LabeledContent("추천으로 시작한 재생") {
                        Text(percent(quality.throughRecommendation)).foregroundStyle(.secondary)
                    }
                    LabeledContent("30초 안에 넘긴 비율") {
                        Text(percent(quality.earlySkipRate)).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("최근 30일")
                } footer: {
                    Text("추천이 실제로 일하고 있는지 보는 값입니다. 기기 안에만 있고 서버로 보내지 않습니다.")
                }

                Section("기기에 쌓인 것") {
                    HStack {
                        Text("즐겨찾기")
                        Spacer()
                        Text("\(favorites.count)개").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("청취 기록")
                        Spacer()
                        Text("\(sessions.count)건").foregroundStyle(.secondary)
                    }
                    Button("청취 기록 지우기", role: .destructive) {
                        isEraseConfirmPresented = true
                    }
                    .disabled(sessions.isEmpty)
                }

                Section {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(AppConfig.appVersion).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("알람은 M6, 히든 라디오 해제는 M7 에서 이 화면에 붙습니다.")
                }
            }
            .navigationTitle("설정")
            .task { await reasoner.warmUp() }
            .confirmationDialog(
                "청취 기록을 모두 지웁니다",
                isPresented: $isEraseConfirmPresented,
                titleVisibility: .visible
            ) {
                Button("지우기", role: .destructive) {
                    ListeningStore(context: modelContext).eraseAll()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("기록 탭의 월간 리포트도 함께 비워집니다. 되돌릴 수 없습니다.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(OnDeviceReasoner())
        .modelContainer(for: [Favorite.self, ListeningSession.self], inMemory: true)
}
