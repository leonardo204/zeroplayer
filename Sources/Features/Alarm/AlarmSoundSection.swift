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

    /// 미디어 볼륨(0…1). 고른 곡은 알람 볼륨이 아니라 이 값을 따른다.
    @State private var mediaVolume: Float = AVAudioSession.sharedInstance().outputVolume

    private var tone: AlarmTone? { AlarmSoundCatalog.tone(id: toneID) }

    var body: some View {
        Section {
            NavigationLink {
                AlarmTonePicker(toneID: $toneID, volume: volume, preview: preview)
            } label: {
                HStack {
                    Text("알람음")
                    Spacer()
                    Text(tone?.label ?? String(localized: "기본음"))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let tone {
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

                // 고른 곡은 미디어 볼륨으로 난다. 지금 그 볼륨이 낮으면 미리 알린다.
                if mediaVolume < 0.3 {
                    Label("미디어 볼륨이 낮으면 고른 곡이 작게 들리거나 안 들릴 수 있습니다.",
                          systemImage: "speaker.slash")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Button {
                    preview.toggle(tone: tone, volume: volume)
                } label: {
                    Label(
                        preview.playingID == tone.id ? "미리듣기 멈추기" : "미리듣기",
                        systemImage: preview.playingID == tone.id ? "stop.fill" : "play.fill")
                }
            }
        } header: {
            Text("알람음")
        } footer: {
            Text(toneID == nil
                 ? String(localized: "기본음은 끌 때까지 반복해서 울리고 가장 크게 납니다. 음량은 기기의 알람 볼륨을 따릅니다.")
                 : String(localized: "고른 곡은 한 번 울리고 끝납니다. 못 듣고 지나치지 않게 2분 간격으로 몇 번 더 겁니다. 미리듣기는 지금 기기 음량으로 들립니다."))
        }
        .onDisappear { preview.stop() }
        // `outputVolume` 은 KVO 로만 바뀜을 알린다. 화면에 있는 동안 지켜본다.
        .task {
            let session = AVAudioSession.sharedInstance()
            mediaVolume = session.outputVolume
            for await value in session.publisher(for: \.outputVolume).values {
                mediaVolume = value
            }
        }
    }
}

/// 알람음 고르는 화면. 누르면 그 자리에서 들려준다.
private struct AlarmTonePicker: View {
    @Binding var toneID: String?
    let volume: Double
    let preview: AlarmSoundPreview

    var body: some View {
        List {
            Section {
                row(title: String(localized: "기본음"),
                    detail: String(localized: "애플 알람음 · 끌 때까지 반복, 가장 큼"),
                    isOn: toneID == nil) {
                    preview.stop()
                    toneID = nil
                }
            }

            Section {
                ForEach(AlarmSoundCatalog.tones) { tone in
                    row(title: tone.label, detail: tone.detail, isOn: toneID == tone.id,
                        isPlaying: preview.playingID == tone.id) {
                        toneID = tone.id
                        preview.play(tone: tone, volume: volume)
                    }
                }
            } header: {
                Text("고전 멜로디")
            } footer: {
                Text("저작권이 끝난 곡을 직접 연주해 담았습니다. 누르면 들려줍니다.")
            }
        }
        .navigationTitle("알람음")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }

    private func row(
        title: String, detail: String, isOn: Bool, isPlaying: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            // `.plain` 단추는 글자에만 터치가 걸린다. `Spacer` 로 벌린 빈 곳은
            // 눌러도 안 잡힌다. 그래서 줄 전체를 터치 영역으로 만든다.
            //
            // 이 줄이 **단추 안쪽**에 있어야 한다. 밖에 두면 단추를 감싼 뷰의
            // 터치 영역만 넓어지고, 그 자리에는 받을 제스처가 없어서 아무 일도
            // 일어나지 않는다(실제로 그랬다).
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

/// 미리듣기 재생기. 편집 화면에서만 쓴다.
///
/// 번들 음원을 그대로 재생한다. 음량은 파일을 다시 굽지 않고 재생기 쪽에서 맞춘다.
/// '점점 크게' 는 빼고 들려준다 — 앞 10초에 걸쳐 오르는데 그 앞부분만 들으면
/// 소리가 안 난다고 오해한다.
@MainActor
@Observable
final class AlarmSoundPreview {
    /// 지금 들려주고 있는 알람음의 키. 없으면 멈춘 상태다.
    private(set) var playingID: String?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var stopTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")

    /// 한 곡 길이가 25초를 넘어서 끝까지 듣게 두지 않는다.
    private static let previewSeconds: Double = 14

    func toggle(tone: AlarmTone, volume: Double) {
        if playingID == tone.id { stop() } else { play(tone: tone, volume: volume) }
    }

    func play(tone: AlarmTone, volume: Double) {
        stop()
        guard let url = AlarmSoundCatalog.bundleURL(for: tone) else {
            log.error("미리듣기 파일이 없다: \(tone.resourceName, privacy: .public)")
            return
        }
        do {
            // 무음 스위치를 내려 둔 채 눌러도 들려야 해서 카테고리만 맞춘다.
            // 세션을 직접 켜고 끄지는 않는다 — 오디오 세션은 앱에 하나뿐이라
            // 여기서 내리면 듣고 있던 방송까지 같이 끊긴다.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            // 슬라이더 값을 그대로 쓴다. 실제 파일도 같은 기울기로 줄여 굽는다.
            player.volume = Float(0.3 + 0.7 * min(1, max(0, volume)))
            player.play()
            self.player = player
            playingID = tone.id
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.previewSeconds))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            log.error("미리듣기를 못 틀었다: \(String(describing: error), privacy: .private)")
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        player?.stop()
        player = nil
        playingID = nil
    }
}
