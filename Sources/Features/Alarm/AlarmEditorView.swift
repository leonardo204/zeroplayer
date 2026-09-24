import SwiftData
import SwiftUI

/// 알람 하나를 만들거나 고친다.
struct AlarmEditorView: View {
    /// nil 이면 새로 만든다.
    var alarm: AlarmSetting?

    @Environment(PushRegistrar.self) private var push
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var time = Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var label = String(localized: "알람")
    @State private var sourceKind: AlarmSourceKind = .auto
    @State private var situation: Situation = .wake
    @State private var sourceID: String?
    @State private var sourceTitle: String?
    @State private var isPickerPresented = false
    @State private var isLoaded = false

    private static let weekdayNames = ["", String(localized: "일"), String(localized: "월"),
                                       String(localized: "화"), String(localized: "수"), String(localized: "목"),
                                       String(localized: "금"), String(localized: "토")]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("시각", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                Section("반복") {
                    weekdayPicker
                    HStack(spacing: 8) {
                        quickButton(String(localized: "평일"), [2, 3, 4, 5, 6])
                        quickButton(String(localized: "주말"), [1, 7])
                        quickButton(String(localized: "매일"), [1, 2, 3, 4, 5, 6, 7])
                        quickButton(String(localized: "한 번만"), [])
                    }
                }

                Section {
                    Picker("소스", selection: $sourceKind) {
                        Text(AlarmSourceKind.auto.label).tag(AlarmSourceKind.auto)
                        Text(AlarmSourceKind.station.label).tag(AlarmSourceKind.station)
                    }
                    .pickerStyle(.segmented)

                    if sourceKind == .auto {
                        Picker("상황", selection: $situation) {
                            ForEach(Situation.allCases, id: \.self) { value in
                                Text(value.label).tag(value)
                            }
                        }
                    } else {
                        Button {
                            isPickerPresented = true
                        } label: {
                            HStack {
                                Text("방송국")
                                Spacer()
                                Text(sourceTitle ?? "고르기")
                                    .foregroundStyle(sourceTitle == nil ? .secondary : .primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("무엇을 틀지")
                } footer: {
                    Text(sourceKind == .auto
                         ? String(localized: "울릴 때 그 시각에 맞는 방송을 서버가 골라 알려 줍니다.")
                         : String(localized: "지정한 방송국이 그대로 재생됩니다."))
                }

                Section("이름") {
                    TextField("알람", text: $label)
                }

                if push.permission != .granted {
                    Section {
                        Label("알림이 꺼져 있어 지금은 울리지 않습니다.", systemImage: "bell.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(alarm == nil ? "알람 추가" : "알람 고치기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { Task { await save() } }
                        .disabled(sourceKind == .station && sourceID == nil)
                }
            }
            .sheet(isPresented: $isPickerPresented) {
                StationPickerView { station in
                    sourceID = station.id
                    sourceTitle = station.name
                }
            }
            .task { load() }
        }
    }

    // MARK: - 조각

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                Button {
                    if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(Self.weekdayNames[day])
                        .font(.footnote.weight(weekdays.contains(day) ? .bold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            weekdays.contains(day) ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(weekdays.contains(day) ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Self.weekdayNames[day])요일")
                .accessibilityAddTraits(weekdays.contains(day) ? .isSelected : [])
            }
        }
    }

    private func quickButton(_ title: String, _ days: Set<Int>) -> some View {
        Button(title) { weekdays = days }
            .font(.caption)
            .buttonStyle(.bordered)
    }

    // MARK: - 동작

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let alarm else { return }
        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        time = Calendar.current.date(from: components) ?? Date()
        weekdays = alarm.weekdays
        label = alarm.label
        sourceKind = alarm.sourceKind
        situation = alarm.situation ?? .wake
        sourceID = alarm.sourceID
        sourceTitle = alarm.sourceTitle
    }

    private func save() async {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let store = AlarmStore(context: modelContext)

        // 알람을 처음 켜는 자리다. 여기서 알림 권한을 묻는다.
        if push.permission == .notAsked {
            await push.requestPermission()
        }

        if let alarm {
            alarm.hour = parts.hour ?? 7
            alarm.minute = parts.minute ?? 0
            alarm.weekdays = weekdays
            alarm.timezoneID = TimeZone.current.identifier
            alarm.label = label.isEmpty ? String(localized: "알람") : label
            alarm.sourceKind = sourceKind
            alarm.sourceID = sourceKind == .auto ? nil : sourceID
            alarm.sourceTitle = sourceKind == .auto ? nil : sourceTitle
            alarm.situation = sourceKind == .auto ? situation : nil
            await store.update(alarm)
        } else {
            let created = AlarmSetting(
                hour: parts.hour ?? 7,
                minute: parts.minute ?? 0,
                weekdays: weekdays,
                sourceKind: sourceKind,
                sourceID: sourceKind == .auto ? nil : sourceID,
                sourceTitle: sourceKind == .auto ? nil : sourceTitle,
                situation: sourceKind == .auto ? situation : nil,
                label: label.isEmpty ? String(localized: "알람") : label
            )
            await store.add(created)
        }
        dismiss()
    }
}
