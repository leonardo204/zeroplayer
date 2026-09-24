import AppTrackingTransparency
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PushRegistrar.self) private var push
    @Query private var alarms: [AlarmSetting]
    @Environment(OnDeviceReasoner.self) private var reasoner
    @Environment(AdConsent.self) private var adConsent
    @Environment(HiddenAccess.self) private var hidden
    @Query private var favorites: [Favorite]
    @Query private var sessions: [ListeningSession]

    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.system.rawValue
    @AppStorage("zp.timer.defaultMinutes") private var defaultMinutes = 45
    @AppStorage("zp.timer.fadeSeconds") private var fadeSeconds = 30

    @State private var isEraseConfirmPresented = false
    /// 버전 라벨을 누른 횟수. 12번이면 지상파가 열린다. 화면에 세는 표시는 두지 않는다.
    @State private var versionTaps = 0
    @State private var isUnlocking = false
    @State private var unlockError: String?
    @State private var isHideConfirmPresented = false

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
        quality.total == 0 ? String(localized: "기록 없음") : "\(Int((value * 100).rounded()))%"
    }

    private var alarmSummary: String {
        let on = alarms.filter(\.isEnabled)
        if on.isEmpty { return alarms.isEmpty ? String(localized: "없음") : String(localized: "전부 꺼짐") }
        guard let next = on.min(by: { ($0.hour, $0.minute) < ($1.hour, $1.minute) }) else { return String(localized: "없음") }
        return on.count == 1 ? next.timeText : String(localized: "\(next.timeText) 외 \(on.count - 1)개")
    }

    private var pushNote: String {
        switch push.permission {
        case .granted:
            return push.hasToken
                ? String(localized: "알림이 켜져 있습니다. 알람은 서버에서 보내고, 서버에 닿지 못하면 기기에 걸어 둔 백업 알림이 울립니다.")
                : String(localized: "알림은 켜져 있지만 아직 기기가 APNs 에 등록되지 않았습니다. 시뮬레이터에서는 등록돼도 푸시가 도착하지 않습니다.")
        case .denied:
            return String(localized: "알림이 꺼져 있어 알람이 울리지 않습니다. 설정 앱에서 켜 주세요.")
        case .notAsked:
            return String(localized: "알람을 처음 만들 때 알림 권한을 묻습니다.")
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

                Section {
                    Picker("테마", selection: $themeRaw) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme.rawValue)
                        }
                    }
                    Button {
                        AppLanguage.openSystemSettings()
                    } label: {
                        HStack {
                            Text("언어")
                            Spacer()
                            Text(AppLanguage.label).foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.forward.square")
                                .font(.footnote)
                                .foregroundStyle(.tint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("iOS 설정 앱의 언어 화면을 엽니다")
                } header: {
                    Text("화면")
                } footer: {
                    Text("언어는 iOS 설정 앱에서 바꿉니다. 누르면 그 화면이 열리고, 고르면 앱이 다시 열리며 바뀝니다.")
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
                    LabeledContent("Apple Intelligence") {
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
                        Text("광고")
                        Spacer()
                        Text(adStateText).foregroundStyle(.secondary)
                    }
                    if adConsent.privacyOptionsRequired {
                        Button("광고 설정 바꾸기") {
                            Task { await adConsent.presentPrivacyOptions() }
                        }
                    }
                } footer: {
                    Text(String(localized: "재생 화면과 알람이 울려 열린 화면에는 광고를 붙이지 않습니다. ")
                         + String(localized: "청취 기록은 기기에만 있고 광고에 쓰이지 않습니다."))
                }

                if hidden.isUnlocked {
                    Section("지상파 라디오") {
                        Label("탐색 탭에서 들을 수 있습니다", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.subheadline)
                        Button("목록에서 숨기기", role: .destructive) {
                            isHideConfirmPresented = true
                        }
                    }
                }

                Section {
                    HStack {
                        Text("버전")
                        Spacer()
                        if isUnlocking {
                            ProgressView()
                        } else {
                            Text(AppConfig.appVersion).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { countVersionTap() }
                } footer: {
                    if let unlockError {
                        Text(unlockError).foregroundStyle(.red)
                    }
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
            .confirmationDialog(
                "지상파 라디오를 숨깁니다",
                isPresented: $isHideConfirmPresented,
                titleVisibility: .visible
            ) {
                Button("숨기기", role: .destructive) { Task { await hideRadio() } }
                Button("취소", role: .cancel) {}
            } message: {
                Text("탐색 탭에서 사라집니다. 같은 방법으로 다시 열 수 있습니다.")
            }
        }
    }

    /// 설정 화면의 광고 한 줄. 무엇이 막고 있는지 그대로 보여 준다.
    private var adStateText: String {
        var parts: [String] = []
        parts.append(adConsent.canShowAds ? String(localized: "표시") : String(localized: "표시 안 함"))
        if AdUnits.isUsingTestUnits { parts.append(String(localized: "테스트 단위")) }
        switch adConsent.trackingStatus {
        case .authorized: parts.append(String(localized: "추적 허용"))
        case .denied, .restricted: parts.append(String(localized: "추적 거부"))
        case .notDetermined: parts.append(String(localized: "추적 미응답"))
        @unknown default: break
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - 지상파 해제

    /// 1.x 는 40번 누르고 `exit(0)` 으로 앱을 껐다. 애플이 금지하는 동작이라
    /// 12번으로 줄이고 앱을 끄지 않는다(`docs/05-ads-policy.md`).
    private func countVersionTap() {
        guard !hidden.isUnlocked, !isUnlocking else { return }
        versionTaps += 1
        guard versionTaps >= HiddenAccess.tapsToUnlock else { return }
        versionTaps = 0
        Task { await unlockRadio() }
    }

    private func unlockRadio() async {
        isUnlocking = true
        unlockError = nil
        defer { isUnlocking = false }
        do {
            let result = try await ProxyClient().unlockHidden()
            hidden.store(token: result.token)
        } catch {
            unlockError = (error as? ProxyError)?.errorDescription ?? String(localized: "지금은 열 수 없습니다.")
        }
    }

    private func hideRadio() async {
        if let token = hidden.token {
            try? await ProxyClient().lockHidden(token: token)
        }
        hidden.forget()
    }
}

#Preview {
    SettingsView()
        .environment(OnDeviceReasoner())
        .modelContainer(for: [Favorite.self, ListeningSession.self], inMemory: true)
}
