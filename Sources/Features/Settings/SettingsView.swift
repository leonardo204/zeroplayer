import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PushRegistrar.self) private var push
    @Query private var alarms: [AlarmSetting]
    @Environment(OnDeviceReasoner.self) private var reasoner
    @Query private var favorites: [Favorite]
    @Query private var sessions: [ListeningSession]

    @AppStorage("zp.timer.defaultMinutes") private var defaultMinutes = 45
    @AppStorage("zp.timer.fadeSeconds") private var fadeSeconds = 30

    @State private var isEraseConfirmPresented = false

    /// 알람 화면을 손으로 누르지 않고 열어 확인하려고 둔 통로다.
    /// `-ZPOpenAlarms 1` 로 켠다. 릴리스 빌드에서는 항상 닫혀 있다.
    @State private var isAlarmsOpen = {
        #if DEBUG
        UserDefaults.standard.string(forKey: "ZPOpenAlarms") == "1"
        #else
        false
        #endif
    }()

    /// 추천 품질 지표. 기록이 바뀔 때만 다시 센다.
    private var quality: (throughRecommendation: Double, earlySkipRate: Double, total: Int) {
        ListeningStore(context: modelContext)
            .recommendationQuality(since: Date().addingTimeInterval(-30 * 24 * 60 * 60))
    }

    private func percent(_ value: Double) -> String {
        quality.total == 0 ? "기록 없음" : "\(Int((value * 100).rounded()))%"
    }

    private var alarmSummary: String {
        let on = alarms.filter(\.isEnabled)
        if on.isEmpty { return alarms.isEmpty ? "없음" : "전부 꺼짐" }
        guard let next = on.min(by: { ($0.hour, $0.minute) < ($1.hour, $1.minute) }) else { return "없음" }
        return on.count == 1 ? next.timeText : "\(next.timeText) 외 \(on.count - 1)개"
    }

    private var pushNote: String {
        switch push.permission {
        case .granted:
            return push.hasToken
                ? "알림이 켜져 있습니다. 알람은 서버에서 보내고, 서버에 닿지 못하면 기기에 걸어 둔 백업 알림이 울립니다."
                : "알림은 켜져 있지만 아직 기기가 APNs 에 등록되지 않았습니다. 시뮬레이터에서는 등록돼도 푸시가 도착하지 않습니다."
        case .denied:
            return "알림이 꺼져 있어 알람이 울리지 않습니다. 설정 앱에서 켜 주세요."
        case .notAsked:
            return "알람을 처음 만들 때 알림 권한을 묻습니다."
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AlarmsView()
                    } label: {
                        HStack {
                            Label("알람", systemImage: "alarm")
                            Spacer()
                            Text(alarmSummary)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(pushNote)
                }

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
                    Text("히든 라디오 해제는 M7 에서 이 화면에 붙습니다.")
                }
            }
            .navigationTitle("설정")
            .navigationDestination(isPresented: $isAlarmsOpen) { AlarmsView() }
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
