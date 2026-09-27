import AVFoundation

// 악보 텍스트를 읽어 사운드폰트로 연주하고 WAV 로 굽는다.
// 쓰임: render <사운드폰트.sf2> <악보.txt> <출력.wav>
//
// 악보 문법
//   sr   44100
//   dur  26.0
//   rev  18            리버브 wet 비율(0~100)
//   inst <슬롯> <GM프로그램> <볼륨0~1> <팬-1~1>
//   note <슬롯> <시작초> <길이초> <미디음번호> <세기0~127>

struct Ev { var frame: AVAudioFramePosition; var slot: Int; var note: UInt8; var vel: UInt8; var on: Bool }

let args = CommandLine.arguments
guard args.count == 4 else { FileHandle.standardError.write("쓰임: render <sf2> <score> <out.wav>\n".data(using:.utf8)!); exit(2) }
let sfURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[3])
let text = try String(contentsOfFile: args[2], encoding: .utf8)

var sr = 44100.0, dur = 26.0, revMix: Float = 16
var instConf: [Int: (UInt8, Float, Float, Float)] = [:]
var events: [Ev] = []
var rawNotes: [(Int, Double, Double, UInt8, UInt8)] = []

for line in text.split(separator: "\n") {
    let t = line.split(separator: " ").map(String.init)
    guard let head = t.first, !head.hasPrefix("#") else { continue }
    switch head {
    case "sr":   sr = Double(t[1]) ?? sr
    case "dur":  dur = Double(t[1]) ?? dur
    case "rev":  revMix = Float(t[1]) ?? revMix
    case "inst": instConf[Int(t[1])!] = (UInt8(t[2])!, Float(t[3])!, Float(t[4])!, t.count > 5 ? Float(t[5])! : 0)
    case "note": rawNotes.append((Int(t[1])!, Double(t[2])!, Double(t[3])!, UInt8(t[4])!, UInt8(t[5])!))
    default: break
    }
}

let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
let engine = AVAudioEngine()
let reverb = AVAudioUnitReverb()
reverb.loadFactoryPreset(.mediumHall)
reverb.wetDryMix = revMix
engine.attach(reverb)
engine.connect(reverb, to: engine.mainMixerNode, format: fmt)

var samplers: [Int: AVAudioUnitSampler] = [:]
for (slot, conf) in instConf {
    let s = AVAudioUnitSampler()
    engine.attach(s)
    engine.connect(s, to: reverb, format: fmt)
    samplers[slot] = s
    _ = conf
}
// 악기를 먼저 불러온다. 렌더링을 켠 뒤에 부르면 첫 음들이 빈 악기로 나가면서
// 결과 크기가 실행마다 달라진다(실제로 그랬다).
for (slot, conf) in instConf {
    guard let s = samplers[slot] else { continue }
    // 0x79 = 멜로디 뱅크. 타악기는 0x78 이지만 여기서는 쓰지 않는다.
    try s.loadSoundBankInstrument(at: sfURL, program: conf.0, bankMSB: 0x79, bankLSB: 0)
    s.volume = conf.1
    s.pan = conf.2
    // 사운드폰트마다 표본 크기가 달라서 현은 아주 작게 난다. 여기서 올려 둔다.
    s.masterGain = conf.3
}
try engine.enableManualRenderingMode(.offline, format: fmt, maximumFrameCount: 4096)
try engine.start()

for n in rawNotes {
    events.append(Ev(frame: AVAudioFramePosition(n.1 * sr), slot: n.0, note: n.3, vel: n.4, on: true))
    events.append(Ev(frame: AVAudioFramePosition((n.1 + n.2) * sr), slot: n.0, note: n.3, vel: 0, on: false))
}
events.sort { $0.frame < $1.frame }

let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sr, AVNumberOfChannelsKey: 2,
    AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
]
var outFile: AVAudioFile? = try AVAudioFile(forWriting: outURL, settings: settings)
let block: AVAudioFrameCount = 256
let buf = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: block)!
// 워밍업. 여기서 나온 소리는 버린다.
for _ in 0..<40 { _ = try engine.renderOffline(block, to: buf) }

let total = AVAudioFramePosition(dur * sr)
var pos: AVAudioFramePosition = 0
var idx = 0

while pos < total {
    let frames = AVAudioFrameCount(min(AVAudioFramePosition(block), total - pos))
    // 이 블록 안에 든 이벤트를 먼저 보낸다. 블록이 256프레임이라 오차는 6밀리초다.
    while idx < events.count, events[idx].frame < pos + AVAudioFramePosition(frames) {
        let e = events[idx]
        if let s = samplers[e.slot] {
            if e.on { s.startNote(e.note, withVelocity: e.vel, onChannel: 0) }
            else { s.stopNote(e.note, onChannel: 0) }
        }
        idx += 1
    }
    let status = try engine.renderOffline(frames, to: buf)
    guard status == .success else { FileHandle.standardError.write("렌더 실패 \(status.rawValue)\n".data(using:.utf8)!); exit(1) }
    try outFile!.write(from: buf)
    pos += AVAudioFramePosition(buf.frameLength)
}
engine.stop()
// 헤더의 길이 값은 파일 객체가 풀릴 때 채워진다. 명시적으로 놓아 준다.
outFile = nil
print("OK \(outURL.lastPathComponent) \(String(format: "%.1f", dur))초")
