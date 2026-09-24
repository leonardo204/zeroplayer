import SwiftData
import SwiftUI

/// 프리셋 하나를 만들거나 고친다. `preset` 이 nil 이면 새로 만든다.
struct PresetEditorView: View {
    let preset: Preset?
    var order: Int = 0

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var symbolName = Preset.symbolChoices[0]
    @State private var sourceKind: PresetSourceKind = .auto
    @State private var situation: Situation = .sleep
    @State private var stationID: String?
    @State private var stationTitle: String?
    @State private var timerMinutes = 45
    @State private var fadeOutSeconds = 30
    @State private var isPickingStation = false

    private static let timerChoices = [0, 15, 30, 45, 60, 90, 120]
    private static let fadeChoices = [0, 10, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section("이름과 아이콘") {
                    TextField("이름", text: $name)
                    symbolPicker
                }

                Section("소스") {
                    Picker("고르는 방식", selection: $sourceKind) {
                        ForEach(PresetSourceKind.allCases, id: \.self) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch sourceKind {
                    case .auto:
                        Picker("상황", selection: $situation) {
                            ForEach(Situation.allCases, id: \.self) { value in
                                Label(value.label, systemImage: value.symbolName).tag(value)
                            }
                        }
                        Text("누를 때마다 지금 시각과 요일에 맞는 방송을 서버에서 골라 옵니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .station:
                        Button {
                            isPickingStation = true
                        } label: {
                            HStack {
                                Group {
                                    if let stationTitle { Text(stationTitle) } else { Text("방송국 고르기") }
                                }
                                    .foregroundStyle(stationTitle == nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("자동 종료") {
                    Picker("타이머", selection: $timerMinutes) {
                        ForEach(Self.timerChoices, id: \.self) { minutes in
                            Text(minutes == 0 ? "쓰지 않음" : "\(minutes)분").tag(minutes)
                        }
                    }
                    if timerMinutes > 0 {
                        Picker("페이드아웃", selection: $fadeOutSeconds) {
                            ForEach(Self.fadeChoices, id: \.self) { seconds in
                                Text(seconds == 0 ? "없음" : "\(seconds)초").tag(seconds)
                            }
                        }
                    }
                }

                if preset != nil {
                    Section {
                        Button("이 프리셋 삭제", role: .destructive, action: deletePreset)
                    }
                }
            }
            .navigationTitle(preset == nil ? "새 프리셋" : "프리셋 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isPickingStation) {
                StationPickerView { station in
                    stationID = station.id
                    stationTitle = station.name
                }
            }
            .onAppear(perform: load)
        }
    }

    private var symbolPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Preset.symbolChoices, id: \.self) { symbol in
                    Button {
                        symbolName = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.body)
                            .frame(width: 40, height: 40)
                            .background(
                                symbolName == symbol ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.quaternary),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if sourceKind == .station { return stationID != nil }
        return true
    }

    // MARK: - 동작

    private func load() {
        guard let preset else { return }
        name = preset.name
        symbolName = preset.symbolName
        sourceKind = preset.sourceKind
        situation = preset.situation
        stationID = preset.sourceID
        stationTitle = preset.sourceTitle
        timerMinutes = preset.timerMinutes
        fadeOutSeconds = preset.fadeOutSeconds
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let preset {
            preset.name = trimmed
            preset.symbolName = symbolName
            preset.sourceKind = sourceKind
            preset.situation = situation
            preset.sourceID = sourceKind == .station ? stationID : nil
            preset.sourceTitle = sourceKind == .station ? stationTitle : nil
            preset.timerMinutes = timerMinutes
            preset.fadeOutSeconds = fadeOutSeconds
        } else {
            modelContext.insert(Preset(
                name: trimmed,
                symbolName: symbolName,
                sourceKind: sourceKind,
                sourceID: sourceKind == .station ? stationID : nil,
                sourceTitle: sourceKind == .station ? stationTitle : nil,
                situation: situation,
                timerMinutes: timerMinutes,
                fadeOutSeconds: fadeOutSeconds,
                order: order
            ))
        }
        try? modelContext.save()
        dismiss()
    }

    private func deletePreset() {
        guard let preset else { return }
        modelContext.delete(preset)
        try? modelContext.save()
        dismiss()
    }
}
