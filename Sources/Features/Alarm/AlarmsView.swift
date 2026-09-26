import SwiftData
import SwiftUI

/// 알람 목록. 설정 탭에서 들어온다.
struct AlarmsView: View {
    @Environment(PushRegistrar.self) private var push
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AlarmSetting.hour), SortDescriptor(\AlarmSetting.minute)])
    private var alarms: [AlarmSetting]

    @State private var editing: AlarmSetting?
    @State private var isCreating = false

    private var store: AlarmStore { AlarmStore(context: modelContext) }

    var body: some View {
        List {
            if !push.isAlarmReady {
                Section {
                    permissionRow
                }
            }

            if alarms.isEmpty {
                ContentUnavailableView(
                    "걸어 둔 알람이 없습니다",
                    systemImage: "alarm",
                    description: Text("오른쪽 위 더하기로 알람을 만듭니다.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(alarms) { alarm in
                    row(for: alarm)
                }
                .onDelete(perform: delete)
            }

            Section {
                EmptyView()
            } footer: {
                Text(footerText)
            }
        }
        .navigationTitle("알람")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isCreating = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("알람 추가")
            }
        }
        .sheet(isPresented: $isCreating) {
            AlarmEditorView(alarm: nil)
        }
        .sheet(item: $editing) { alarm in
            AlarmEditorView(alarm: alarm)
        }
        .task { await store.syncAll() }
    }

    // MARK: - 조각

    /// 기기가 어느 길로 알람을 받는지에 따라 안내가 다르다.
    private var footerText: String {
        if AlarmDelivery.isAlarmKitAvailable {
            return String(localized: """
                알람은 무음 모드와 집중 모드에서도 울립니다. 알람 화면에서 '방송 켜기' \
                를 누르면 앱을 열지 않고 방송이 시작됩니다.
                """)
        }
        return String(localized: """
            무음 모드에서는 알람 소리가 나지 않습니다. 알림음은 한 번만 울리고 \
            시계 앱처럼 끌 때까지 반복하지 않습니다. 알림을 눌러야 재생이 시작됩니다.
            """)
    }

    private var permissionRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                AlarmDelivery.isAlarmKitAvailable
                    ? String(localized: "알람 권한이 꺼져 있습니다")
                    : String(localized: "알림이 꺼져 있습니다"),
                systemImage: "bell.slash")
                .font(.subheadline.weight(.semibold))
            Text(permissionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if push.alarmPermission == .denied {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Button(AlarmDelivery.isAlarmKitAvailable
                       ? String(localized: "알람 허용하기")
                       : String(localized: "알림 허용하기")) {
                    Task {
                        await push.requestAlarmPermission()
                        await store.reschedule()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private var permissionText: String {
        switch (AlarmDelivery.isAlarmKitAvailable, push.alarmPermission == .denied) {
        case (true, true):
            return String(localized: "설정 앱에서 zeroPlayer 의 알람을 켜야 울립니다.")
        case (true, false):
            return String(localized: "알람이 울리려면 알람 예약을 허용해야 합니다.")
        case (false, true):
            return String(localized: "설정 앱에서 zeroPlayer 의 알림을 켜야 알람이 울립니다.")
        case (false, false):
            return String(localized: "알람이 울리려면 알림을 허용해야 합니다.")
        }
    }

    private func row(for alarm: AlarmSetting) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(alarm.timeText)
                    // 고정 크기를 쓰면 글자 크기 설정을 키워도 시각만 그대로다.
                    // largeTitle 이 기본 34pt 이고 설정에 따라 함께 커진다.
                    .font(.system(.largeTitle, design: .default, weight: .light).monospacedDigit())
                    .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                Text("\(alarm.repeatText) · \(alarm.label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(alarm.sourceText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { on in Task { await store.toggle(alarm, on: on) } }
            ))
            .labelsHidden()
            .accessibilityLabel("\(alarm.timeText) 알람")
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = alarm }
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { alarms[$0] }
        Task {
            for alarm in targets { await store.delete(alarm) }
        }
    }
}
