import AVFoundation
import Foundation
import os

/// 알람음 하나. 목록에 줄 하나를 더하면 화면의 선택지도 함께 늘어난다.
///
/// 오디오 파일을 번들에 넣지 않고 그때그때 그려서 쓴다. 그래야 음량과
/// '점점 커지기' 를 사용자가 고른 값으로 굽을 수 있다. 애플은 알람음으로
/// 링형 PCM 만 받고(MP3 는 소리가 안 난다) 길이도 30초 미만이어야 한다.
struct AlarmTone: Identifiable, Hashable, Sendable {
    /// 파일 이름과 저장값에 쓰는 키. 한번 정하면 바꾸지 않는다.
    let id: String
    let label: String
    /// 그리는 방법. 0 부터 흐른 시간(초)을 받아 -1…1 을 돌려준다.
    let shape: @Sendable (Double) -> Double

    static func == (a: AlarmTone, b: AlarmTone) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum AlarmSoundCatalog {
    /// 알람음 길이. 30초를 넘기면 시스템이 기본음으로 바꿔 버린다.
    static let seconds: Double = 25
    static let sampleRate: Double = 22_050

    /// 고를 수 있는 알람음. 여기에 한 줄을 더하면 편집 화면에 그대로 나온다.
    static let tones: [AlarmTone] = [
        AlarmTone(id: "beep", label: String(localized: "삐삐")) { t in
            square(t, on: 0.25, period: 0.5) * sine(t, 1_046)
        },
        AlarmTone(id: "pulse", label: String(localized: "펄스")) { t in
            square(t, on: 0.12, period: 0.24) * sine(t, 880)
        },
        AlarmTone(id: "chime", label: String(localized: "차임")) { t in
            let step = Int(t / 0.28) % 4
            let notes = [523.25, 659.25, 783.99, 659.25]
            return square(t, on: 0.24, period: 0.28) * sine(t, notes[step])
        },
        AlarmTone(id: "bell", label: String(localized: "종")) { t in
            let phase = t.truncatingRemainder(dividingBy: 1.6)
            let decay = exp(-phase * 2.4)
            return decay * (sine(t, 880) * 0.6 + sine(t, 1_320) * 0.3 + sine(t, 2_640) * 0.1)
        },
        AlarmTone(id: "sweep", label: String(localized: "사이렌")) { t in
            let phase = t.truncatingRemainder(dividingBy: 1.2) / 1.2
            return sine(t, 600 + 500 * phase)
        },
        AlarmTone(id: "urgent", label: String(localized: "경보")) { t in
            let high = Int(t / 0.35) % 2 == 0
            return square(t, on: 0.3, period: 0.35) * sine(t, high ? 1_200 : 1_600)
        },
        AlarmTone(id: "morning", label: String(localized: "아침")) { t in
            let step = Int(t / 0.45) % 3
            let notes = [587.33, 880.0, 1_174.66]
            let phase = t.truncatingRemainder(dividingBy: 0.45)
            let envelope = sin(.pi * min(1, phase / 0.4))
            return envelope * sine(t, notes[step])
        },
        AlarmTone(id: "ripple", label: String(localized: "물결")) { t in
            (0.55 + 0.45 * sin(2 * .pi * 5 * t)) * sine(t, 440)
        },
    ]

    static func tone(id: String?) -> AlarmTone? {
        guard let id else { return nil }
        return tones.first { $0.id == id }
    }

    // MARK: - 그리기

    private static func sine(_ t: Double, _ hz: Double) -> Double {
        sin(2 * .pi * hz * t)
    }

    /// `period` 마다 앞 `on` 초만 소리를 낸다.
    private static func square(_ t: Double, on: Double, period: Double) -> Double {
        t.truncatingRemainder(dividingBy: period) < on ? 1 : 0
    }

    /// 점점 커지기에 쓰는 램프. 앞 `rampSeconds` 동안 0 에서 1 로 오른다.
    private static let rampSeconds: Double = 10

    /// PCM 표본을 그린다. `volume` 은 0…1, 1 이 가장 크다.
    ///
    /// 알람음은 시끄러워야 제 구실을 한다. 그래서 파형을 눌러 포화시켜 소리를
    /// 꽉 채운 뒤, 마지막에 고른 음량까지 끌어올린다. 정규화를 빼면 가장 크게
    /// 맞춰도 최대치의 88% 밖에 안 나온다.
    static func samples(tone: AlarmTone, volume: Double, fadeIn: Bool) -> [Int16] {
        let count = Int(sampleRate * seconds)
        let level = min(1, max(0, volume))
        // 가장 작게 골라도 안 들리면 알람이 아니다. 아래를 잘라 둔다.
        let target = 0.25 + 0.75 * level

        var shaped = [Double](repeating: 0, count: count)
        var loudest = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            // 눌러서 포화시킨다. 그냥 잘라내면 귀에 거슬리는 소리가 난다.
            let value = tanh(tone.shape(t) * 1.8)
            shaped[i] = value
            loudest = max(loudest, abs(value))
        }
        guard loudest > 0.0001 else { return [Int16](repeating: 0, count: count) }

        let scale = target / loudest
        var out = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            var value = shaped[i] * scale
            if fadeIn {
                let t = Double(i) / sampleRate
                value *= min(1, t / rampSeconds)
            }
            out[i] = Int16(max(-1, min(1, value)) * 32_700)
        }
        return out
    }

    static func wavData(tone: AlarmTone, volume: Double, fadeIn: Bool) -> Data {
        var samples = samples(tone: tone, volume: volume, fadeIn: fadeIn)
        var data = Data()
        func le32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func le16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }

        let payload = UInt32(samples.count * 2)
        let rate = UInt32(sampleRate)
        data.append(contentsOf: Array("RIFF".utf8)); le32(36 + payload)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); le32(16)
        le16(1)            // 링형 PCM
        le16(1)            // 모노
        le32(rate)
        le32(rate * 2)     // 초당 바이트
        le16(2)            // 프레임당 바이트
        le16(16)           // 비트
        data.append(contentsOf: Array("data".utf8)); le32(payload)
        samples.withUnsafeMutableBufferPointer { data.append(contentsOf: Data(buffer: $0)) }
        return data
    }
}

/// 알람음 파일을 `Library/Sounds` 에 두고 이름을 돌려준다.
///
/// AlarmKit 과 `UNNotificationSound` 는 둘 다 이 폴더를 본다. 파일은 **울릴 때**
/// 읽히므로(실기기 확인, `docs/10-alarmkit.md`) 미리 써 두기만 하면 된다.
enum AlarmSoundStore {
    private static let prefix = "zp-alarm-"
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")

    static var directory: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let dir = lib.appendingPathComponent("Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 같은 소리·음량이면 파일 하나를 여러 알람이 같이 쓴다.
    static func fileName(tone: AlarmTone, volume: Double, fadeIn: Bool) -> String {
        let step = Int((min(1, max(0, volume)) * 20).rounded())
        return "\(prefix)\(tone.id)-\(step)\(fadeIn ? "-f" : "").wav"
    }

    /// 파일을 만들어 두고 이름을 돌려준다. 이미 있으면 다시 쓰지 않는다.
    @discardableResult
    static func ensure(tone: AlarmTone, volume: Double, fadeIn: Bool) -> String? {
        let name = fileName(tone: tone, volume: volume, fadeIn: fadeIn)
        let url = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { return name }
        do {
            try AlarmSoundCatalog.wavData(tone: tone, volume: volume, fadeIn: fadeIn)
                .write(to: url, options: .atomic)
            return name
        } catch {
            log.error("알람음을 쓰지 못했다: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    /// 지금 걸린 알람이 쓰지 않는 파일을 치운다.
    static func prune(keeping names: Set<String>) {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in items where url.lastPathComponent.hasPrefix(prefix) {
            guard !names.contains(url.lastPathComponent) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
