import AVFoundation
import Foundation
import os

/// 알람음 하나.
///
/// 소리는 저작권이 끝난 고전을 우리가 직접 연주해 구운 것이다. 음원 파일이
/// `Sources/Resources/AlarmTones/zptone-<id>.caf` 로 번들에 들어 있고, 다시 굽는
/// 도구는 `tools/alarm-tones/` 에 있다(악보·렌더러·라이선스 메모).
///
/// 애플은 알람음으로 링형 PCM·IMA4·µLaw·aLaw 만 받는다. MP3 를 넣으면 알람 화면은
/// 뜨는데 소리가 안 난다(실기기 확인, `docs/10-alarmkit.md`). 그래서 번들에는
/// IMA4 로 눌러 담고, 기기에서 링형 PCM WAV 로 풀어 쓴다.
struct AlarmTone: Identifiable, Hashable, Sendable {
    /// 저장값과 파일 이름에 쓰는 키. 한번 정하면 바꾸지 않는다.
    let id: String
    /// 곡 이름.
    let label: String
    /// 목록에서 곡 아래에 붙는 한 줄. 작곡가와 성격이다.
    let detail: String

    /// 번들에 든 음원 파일 이름(확장자 없이).
    var resourceName: String { "zptone-\(id)" }

    static func == (a: AlarmTone, b: AlarmTone) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum AlarmSoundCatalog {
    /// 기기에서 풀어 쓸 때의 표본율. 번들 음원도 같은 값으로 구웠다.
    /// 점점 커지기에 쓰는 램프. 앞 이만큼 동안 0 에서 1 로 오른다.
    static let rampSeconds: Double = 10

    /// 고를 수 있는 알람음. 곡을 더하려면 `tools/alarm-tones/` 에서 구운 뒤
    /// 파일을 `Sources/Resources/AlarmTones/` 에 넣고 여기에 한 줄을 더한다.
    static let tones: [AlarmTone] = [
        AlarmTone(id: "grieg-morning", label: String(localized: "아침"),
                  detail: String(localized: "그리그 · 상쾌한 플루트")),
        AlarmTone(id: "bach-minuet", label: String(localized: "미뉴에트"),
                  detail: String(localized: "바흐 · 경쾌한 오르골")),
        AlarmTone(id: "bach-prelude", label: String(localized: "전주곡"),
                  detail: String(localized: "바흐 · 맑은 첼레스타")),
        AlarmTone(id: "beethoven-joy", label: String(localized: "환희의 송가"),
                  detail: String(localized: "베토벤 · 밝은 현")),
        AlarmTone(id: "pachelbel-canon", label: String(localized: "카논"),
                  detail: String(localized: "파헬벨 · 차분한 하프")),
        AlarmTone(id: "vivaldi-spring", label: String(localized: "봄"),
                  detail: String(localized: "비발디 · 상쾌한 바이올린")),
        AlarmTone(id: "mozart-turca", label: String(localized: "터키 행진곡"),
                  detail: String(localized: "모차르트 · 경쾌한 피아노")),
        AlarmTone(id: "mozart-nacht", label: String(localized: "나흐트무지크"),
                  detail: String(localized: "모차르트 · 경쾌한 현")),
        AlarmTone(id: "bach-cello1", label: String(localized: "무반주 첼로 1번"),
                  detail: String(localized: "바흐 · 차분한 첼로 홀로")),
        AlarmTone(id: "beethoven-elise", label: String(localized: "엘리제를 위하여"),
                  detail: String(localized: "베토벤 · 익숙한 피아노")),
        AlarmTone(id: "mozart-twinkle", label: String(localized: "작은 별"),
                  detail: String(localized: "모차르트 · 밝은 오르골")),
        AlarmTone(id: "mozart-k545", label: String(localized: "소나타 K.545"),
                  detail: String(localized: "모차르트 · 맑은 피아노")),
        AlarmTone(id: "bach-invention1", label: String(localized: "인벤션 1번"),
                  detail: String(localized: "바흐 · 또랑또랑한 하프시코드")),
        AlarmTone(id: "haydn-surprise", label: String(localized: "놀람 교향곡"),
                  detail: String(localized: "하이든 · 경쾌한 현")),
        AlarmTone(id: "dvorak-newworld", label: String(localized: "신세계 2악장"),
                  detail: String(localized: "드보르자크 · 느린 잉글리시 호른")),
        AlarmTone(id: "rossini-tell", label: String(localized: "윌리엄 텔"),
                  detail: String(localized: "로시니 · 확실히 깨우는 트럼펫")),
        AlarmTone(id: "strauss-danube", label: String(localized: "아름다운 도나우"),
                  detail: String(localized: "슈트라우스 · 상쾌한 왈츠")),
        AlarmTone(id: "bach-air", label: String(localized: "에어"),
                  detail: String(localized: "바흐 · 차분한 오보에")),
        AlarmTone(id: "beethoven-fifth", label: String(localized: "교향곡 5번"),
                  detail: String(localized: "베토벤 · 확실히 깨우는 현")),
        AlarmTone(id: "elgar-salut", label: String(localized: "사랑의 인사"),
                  detail: String(localized: "엘가 · 따뜻한 바이올린")),
    ]

    static func tone(id: String?) -> AlarmTone? {
        guard let id else { return nil }
        return tones.first { $0.id == id }
    }

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "alarm")

    /// 번들에 든 음원 주소. 미리듣기는 이 파일을 그대로 재생한다.
    static func bundleURL(for tone: AlarmTone) -> URL? {
        Bundle.main.url(forResource: tone.resourceName, withExtension: "caf")
    }

    // MARK: - 풀어 쓰기

    /// 번들 음원을 읽어 표본과 표본율을 돌려준다. 압축(IMA4)을 풀어 −1…1 로 준다.
    ///
    /// 표본율을 파일에서 읽는 것이 중요하다. 여기에 고정값을 쓰면 음원을 다시 구워
    /// 표본율이 바뀌었을 때 WAV 머리말과 어긋나 소리가 느려지거나 빨라진다.
    private static func decode(_ tone: AlarmTone) -> (samples: [Float], sampleRate: Double)? {
        guard let url = bundleURL(for: tone) else {
            log.error("알람음 파일이 번들에 없다: \(tone.resourceName, privacy: .public)")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            let frames = AVAudioFrameCount(file.length)
            guard frames > 0 else { return nil }
            // 압축 파일은 처리 형식(Float32 비끼움)으로 읽는다.
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: frames) else { return nil }
            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return nil }

            let count = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            var out = [Float](repeating: 0, count: count)
            if channelCount == 1 {
                out.withUnsafeMutableBufferPointer { dst in
                    dst.baseAddress?.update(from: channels[0], count: count)
                }
            } else {
                // 스테레오로 구운 파일이 섞여 들어와도 모노로 눌러 쓴다.
                for i in 0..<count {
                    var sum: Float = 0
                    for c in 0..<channelCount { sum += channels[c][i] }
                    out[i] = sum / Float(channelCount)
                }
            }
            return (out, buffer.format.sampleRate)
        } catch {
            log.error("알람음을 읽지 못했다: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    /// 고른 음량과 '점점 크게' 를 적용해 링형 PCM WAV 를 만든다.
    ///
    /// 번들 음원은 이미 눌러 키워 둔 것이라(RMS 약 −8dBFS) 여기서는 곱하기만 한다.
    /// `volume` 은 0…1 이고, 가장 작게 골라도 안 들리면 알람 구실을 못 하므로
    /// 아래를 잘라 둔다.
    static func wavData(tone: AlarmTone, volume: Double, fadeIn: Bool) -> Data? {
        guard let decoded = decode(tone) else { return nil }
        let source = decoded.samples
        let level = min(1, max(0, volume))
        let gain = Float(0.3 + 0.7 * level)
        let rampFrames = fadeIn ? Int(rampSeconds * decoded.sampleRate) : 0

        var samples = [Int16](repeating: 0, count: source.count)
        for i in 0..<source.count {
            var value = source[i] * gain
            if rampFrames > 0, i < rampFrames {
                value *= Float(i) / Float(rampFrames)
            }
            samples[i] = Int16(max(-1, min(1, value)) * 32_700)
        }
        return wav(samples, sampleRate: decoded.sampleRate)
    }

    /// 링형 PCM 모노 WAV 를 조립한다.
    private static func wav(_ samples: [Int16], sampleRate: Double) -> Data {
        var samples = samples
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
        guard let data = AlarmSoundCatalog.wavData(tone: tone, volume: volume, fadeIn: fadeIn) else {
            // 파일을 못 만들면 기본음으로 떨어진다. 안 울리는 쪽이 더 나쁘다.
            return nil
        }
        do {
            try data.write(to: url, options: .atomic)
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
