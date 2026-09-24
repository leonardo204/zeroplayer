import Foundation
import Observation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

/// 기기 안의 모델이 쓸 수 있는 상태인지.
enum OnDeviceAvailability: Equatable, Sendable {
    case ready
    /// A17 Pro 미만이거나 iOS 26 미만이다.
    case unsupportedDevice
    /// Apple Intelligence 가 꺼져 있다.
    case notEnabled
    /// 모델을 내려받는 중이다.
    case notReady
    /// 쓸 수 있다고 했는데 실제로 답하지 못했다.
    case failing
    case unknown

    var isReady: Bool { self == .ready }

    /// 설정 화면에 그대로 띄우는 문구다.
    var message: String {
        switch self {
        case .ready: String(localized: "Apple Intelligence 로 추천 문구를 다듬습니다.")
        case .unsupportedDevice: String(localized: "이 기기는 Apple Intelligence 를 지원하지 않습니다. 추천은 그대로 나옵니다.")
        case .notEnabled: String(localized: "Apple Intelligence 가 꺼져 있습니다. 추천은 그대로 나옵니다.")
        case .notReady: String(localized: "모델을 내려받는 중입니다. 준비되면 문구가 조금 더 자연스러워집니다.")
        case .failing: String(localized: "Apple Intelligence 가 답하지 못해 쓰지 않습니다. 추천은 그대로 나옵니다.")
        case .unknown: String(localized: "Apple Intelligence 를 쓸 수 없습니다. 추천은 그대로 나옵니다.")
        }
    }
}

/// 기기 안 모델이 맡는 일. 없어도 앱은 그대로 돌아간다.
@MainActor
protocol OnDeviceReasoning: AnyObject {
    var availability: OnDeviceAvailability { get }
    /// 실제로 답하는지 한 번 확인한다. 설정 화면이 상태를 보여 주기 전에 부른다.
    func warmUp() async
    /// 맨 위로 올라온 방송국에 붙일 한 줄. 못 만들면 nil 을 준다.
    func personalNote(for item: RecommendationDTO, situation: Situation, history: [String]) async -> String?
}

/// Apple Foundation Models 를 쓰는 구현.
///
/// 맡기는 일은 짧은 문장 하나뿐이다. `docs/04-curation.md` 5.3 에 적어 둔 대로
/// 세상 지식이 필요한 판단은 서버에 남긴다 — 3B 모델이 이름과 태그만 보고
/// "이 채널이 밤에 어울리는가"를 정할 수는 없다. 순서는 `Personalizer` 가 정하고
/// 기기 모델은 이유만 쓴다.
@MainActor
@Observable
final class OnDeviceReasoner: OnDeviceReasoning {
    @ObservationIgnored private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "ondevice")

    /// 쓸 수 있다고 했는데 실제로는 답하지 못하는 경우가 있다(모델 자산이 아직 없는 기기).
    /// 그래서 첫 호출 결과까지 보고 상태를 정한다. 설정 화면이 이 값을 그대로 보여 준다.
    private(set) var availability: OnDeviceAvailability

    /// 연속 실패 횟수. 두 번 이어 실패하면 더 부르지 않는다.
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var didWarmUp = false

    init() {
        availability = Self.probe()
    }

    /// 같은 방송국에 같은 문장을 두 번 만들지 않는다. 화면을 다시 열 때 기다리지 않게.
    @ObservationIgnored private var cache: [String: String] = [:]

    /// 쓸 수 있다고 나와도 모델 자산이 없어 실제로는 못 만드는 기기가 있다.
    /// 짧은 한 문장을 만들어 보고 그 결과로 상태를 확정한다. 한 번만 돈다.
    func warmUp() async {
        guard availability.isReady, !didWarmUp else { return }
        didWarmUp = true
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return }
        do {
            let session = LanguageModelSession()
            _ = try await session.respond(to: "\"좋은 밤입니다\" 를 그대로 다시 쓴다.")
        } catch {
            log.debug("기기 모델을 시험해 보니 답하지 못한다: \(String(describing: error), privacy: .private)")
            availability = .failing
        }
        #endif
    }

    func personalNote(for item: RecommendationDTO, situation: Situation, history: [String]) async -> String? {
        guard availability.isReady else { return nil }
        let key = "\(situation.rawValue)|\(item.id)"
        if let cached = cache[key] { return cached }

        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return nil }

        let prompt = """
        상황: \(situation.label)
        방송국: \(item.title)
        분류: \(item.tags.prefix(4).joined(separator: ", "))
        분위기: \(item.moods.prefix(3).joined(separator: ", "))
        내가 자주 듣는 것: \(history.prefix(5).joined(separator: ", "))

        이 방송국을 지금 왜 먼저 보여 주는지 한국어 한 문장으로 쓴다.
        35자 이내로, '~합니다' 로 끝낸다. 방송국 이름은 다시 말하지 않는다.
        위에 적힌 것 말고 다른 사실을 지어내지 않는다.
        """

        do {
            let session = LanguageModelSession()
            let answer = try await session.respond(to: prompt)
            let text = answer.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            guard (6...60).contains(text.count) else { return nil }
            failures = 0
            cache[key] = text
            return text
        } catch {
            // 상황을 바꾸면 앞선 요청을 취소한다. 실패로 세면 멀쩡한 기기에서도
            // 두 번 만에 Apple Intelligence 를 꺼 버린다.
            if error is CancellationError { return nil }
            log.debug("Apple Intelligence 가 답하지 못했다: \(String(describing: error), privacy: .private)")
            failures += 1
            if failures >= 2 { availability = .failing }
            return nil
        }
        #else
        return nil
        #endif
    }

    /// 쓸 수 없는 사유 셋(기기 미지원·꺼짐·내려받는 중)은 전부 조용히 넘긴다.
    /// 사용자에게 알리지 않는다. 설정 화면에서만 상태를 보여 준다.
    private static func probe() -> OnDeviceAvailability {
        #if targetEnvironment(simulator)
        // 시뮬레이터에서는 프레임워크를 건드리지 않는다.
        //
        // `availability` 가 `.available` 이라고 답해 놓고 `respond(to:)` 안에서
        // EXC_BAD_ACCESS(SIGSEGV)로 프로세스가 통째로 죽는다. Swift 오류가 아니라
        // 시그널이라 do/catch 로 못 막는다. 모델 자산이 맥에 없을 때 나는 것으로 보인다.
        // 시뮬레이터에서 앱이 조용히 사라지면 이 자리를 먼저 의심한다.
        return .unsupportedDevice
        #elseif canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return .unsupportedDevice }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .unsupportedDevice
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady: return .notReady
            @unknown default: return .unknown
            }
        @unknown default:
            return .unknown
        }
        #else
        return .unsupportedDevice
        #endif
    }
}

/// 기기 모델을 쓰지 않는 자리(미리보기, 테스트)에서 쓴다.
@MainActor
final class NoOnDeviceReasoner: OnDeviceReasoning {
    var availability: OnDeviceAvailability { .unsupportedDevice }
    func warmUp() async {}
    func personalNote(for item: RecommendationDTO, situation: Situation, history: [String]) async -> String? { nil }
}
