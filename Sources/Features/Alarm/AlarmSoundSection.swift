import AVFoundation
import SwiftUI
import os

/// 알람음을 고르고, 음량을 맞추고, 그 자리에서 들어 본다.
///
/// 첫 줄은 iOS 기본음이다. 기본음은 끌 때까지 반복해서 울리고 가장 크게 나오지만
/// 소리를 고를 수 없다. 우리 알람음을 고르면 음량과 '점점 커지기' 가 열리는 대신
/// 한 번만 울린다(애플이 커스텀 알람음의 반복을 아직 지원하지 않는다).
struct AlarmSoundSection: View {
    @Binding var toneID: String?
    @Binding var volume: Double
    @Binding var fadeIn: Bool

    @State private var preview = AlarmSoundPreview()

    var body: some View {
        Section {
            Picker("알람음", selection: $toneID) {
                Text("기본음").tag(String?.none)
                ForEach(AlarmSoundCatalog.tones) { tone in
                    Text(tone.label).tag(String?.some(tone.id))
                }
            }

            if let tone = AlarmSoundCatalog.tone(id: toneID) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $volume, in: 0...1)
                        .accessibilityLabel("알람 음량")
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("점점 크게", isOn: $fadeIn)

                Button {
                    preview.toggle(tone: tone, volume: volume, fadeIn: fadeIn)
                } label: {
                    Label(
                        preview.isPlaying ? "미리듣기 멈추기" : "미리듣기",
                        systemImage: preview.isPlaying ? "stop.fill" : "play.fill")
                }
            }
        } header: {
            Text("알람음")
        } footer: {
            Text(toneID == nil
                 ? String(localized: "기본음은 끌 때까지 반복해서 울리고 가장 크게 납니다. 음량은 설정 앱의 '사운드 및 햅틱 > 벨소리 및 알림' 을 따릅니다.")
                 : String(localized: "고른 소리는 한 번만 울립니다. 못 듣고 지나치지 않게 2분 간격으로 몇 번 더 겁니다. 미리듣기는 지금 기기 음량으로 들리고, 알람은 벨소리 볼륨으로 납니다."))
        }
        .onDisappear { preview.stop() }
    }
}

/// 미리듣기 재생기. 편집 화면에서만 쓴다.
@MainActor
@Observable
final class AlarmSoundPreview {
    private(set) var isPlaying = false

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")

    func toggle(tone: AlarmTone, volume: Double, fadeIn: Bool) {
        if isPlaying { stop(); return }
        // 점점 커지기는 10초에 걸쳐 오르는데 미리듣기에서 그 앞부분만 들으면
        // 소리가 안 난다고 오해한다. 그래서 미리듣기는 램프를 빼고 들려준다.
        let data = AlarmSoundCatalog.wavData(tone: tone, volume: volume, fadeIn: false)
        do {
            // 무음 스위치를 내려 둔 채 눌러도 들려야 해서 카테고리만 맞춘다.
            // 세션을 직접 켜고 끄지는 않는다 — 오디오 세션은 앱에 하나뿐이라
            // 여기서 내리면 듣고 있던 방송까지 같이 끊긴다.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            let player = try AVAudioPlayer(data: data)
            player.numberOfLoops = 0
            player.volume = 1
            player.play()
            self.player = player
            isPlaying = true
            // 알람음 전체는 25초라 끝까지 듣게 두지 않는다.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(6))
                self?.stop()
            }
        } catch {
            log.error("미리듣기를 못 틀었다: \(String(describing: error), privacy: .private)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}
