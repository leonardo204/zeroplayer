import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @Query private var sessions: [ListeningSession]

    @AppStorage("zp.timer.defaultMinutes") private var defaultMinutes = 45
    @AppStorage("zp.timer.fadeSeconds") private var fadeSeconds = 30

    @State private var isEraseConfirmPresented = false

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
        .modelContainer(for: [Favorite.self, ListeningSession.self], inMemory: true)
}
