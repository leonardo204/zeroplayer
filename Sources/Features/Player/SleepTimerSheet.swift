import SwiftUI

/// 자동 종료 타이머를 걸고 끄는 화면. 프리셋 버튼과 직접 입력을 함께 둔다.
struct SleepTimerSheet: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    @AppStorage("zp.timer.defaultMinutes") private var defaultMinutes = 45
    @AppStorage("zp.timer.fadeSeconds") private var fadeSeconds = 30

    @State private var customMinutes = 20

    private static let choices = [15, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            List {
                if let remaining = player.sleepTimer.remainingText {
                    Section("지금 걸린 타이머") {
                        HStack {
                            Label(remaining, systemImage: "timer")
                                .monospacedDigit()
                            Spacer()
                            if player.sleepTimer.isFading {
                                Text("페이드아웃 중")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("10분 늘리기") { player.sleepTimer.extend(minutes: 10) }
                        Button("타이머 끄기", role: .destructive) {
                            player.cancelSleepTimer()
                            dismiss()
                        }
                    }
                }

                Section("시간 고르기") {
                    HStack(spacing: 8) {
                        ForEach(Self.choices, id: \.self) { minutes in
                            Button {
                                start(minutes)
                            } label: {
                                Text("\(minutes)")
                                    .font(.callout.weight(.medium))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(minutes)분 뒤 종료")
                        }
                    }
                    .padding(.vertical, 4)

                    Stepper("직접 입력 \(customMinutes)분", value: $customMinutes, in: 1...240, step: 5)
                    Button("\(customMinutes)분으로 시작") { start(customMinutes) }
                }

                Section {
                    Picker("페이드아웃", selection: $fadeSeconds) {
                        ForEach([0, 10, 30, 60], id: \.self) { seconds in
                            Text(seconds == 0 ? "없음" : "\(seconds)초").tag(seconds)
                        }
                    }
                } footer: {
                    Text("끝나기 전 이 시간 동안 볼륨을 0 으로 내립니다. 뚝 끊기지 않습니다.")
                }
            }
            .navigationTitle("자동 종료")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear { customMinutes = defaultMinutes }
        }
    }

    private func start(_ minutes: Int) {
        player.startSleepTimer(minutes: minutes, fadeOutSeconds: fadeSeconds)
        defaultMinutes = minutes
        dismiss()
    }
}
