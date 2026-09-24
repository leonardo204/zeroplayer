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
            if push.permission != .granted {
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
                Text("""
                무음 모드에서는 알람 소리가 나지 않습니다. 알림음은 한 번만 울리고 \
                시계 앱처럼 끌 때까지 반복하지 않습니다. 알림을 눌러야 재생이 시작됩니다.
                """)
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

    private var permissionRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("알림이 꺼져 있습니다", systemImage: "bell.slash")
                .font(.subheadline.weight(.semibold))
            Text(push.permission == .denied
                 ? "설정 앱에서 zeroPlayer 의 알림을 켜야 알람이 울립니다."
                 : "알람이 울리려면 알림을 허용해야 합니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if push.permission == .denied {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Button("알림 허용하기") {
                    Task { await push.requestPermission() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private func row(for alarm: AlarmSetting) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(alarm.timeText)
                    .font(.system(size: 34, weight: .light).monospacedDigit())
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
