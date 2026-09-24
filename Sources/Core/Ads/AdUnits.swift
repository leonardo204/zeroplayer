import Foundation

/// 광고 단위 ID. 값은 빌드 설정에서 Info.plist 로 주입된다.
///
/// 개발 빌드는 `Configs/Debug.xcconfig` 의 구글 테스트 ID 를, 배포 빌드는
/// `Configs/Release.xcconfig` 의 실제 단위를 쓴다. 개발 중에 실제 광고를 누르면
/// 무효 트래픽이 되어 게시자 계정이 막힐 수 있어서 둘을 갈라 뒀다.
enum AdUnits {
    /// 이 자리에 쓸 광고 단위 ID. 배너를 붙이지 않는 자리는 nil 이다.
    static func unitID(for slot: AdSlot) -> String? {
        guard let key = infoKey(for: slot) else { return nil }
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func infoKey(for slot: AdSlot) -> String? {
        switch slot {
        case .recommendList: return "ZPAdUnitRecommend"
        case .discoverList: return "ZPAdUnitDiscover"
        case .presetList: return "ZPAdUnitPresets"
        case .statsList: return "ZPAdUnitStats"
        case .player, .hiddenRadio, .afterAlarm: return nil
        }
    }

    /// 구글이 공개한 테스트 계정의 게시자 번호.
    private static let testPublisher = "3940256099942544"

    /// 지금 붙어 있는 값 가운데 하나라도 구글 테스트 ID 인지. 설정 화면에 그대로 보여 준다.
    ///
    /// 앱 ID 만 보지 않는 이유는 둘이 어긋날 수 있기 때문이다. 실제 광고 단위에
    /// 테스트 앱 ID 를 붙이면 광고가 나가지 않는데, 앱 ID 만 보면 그 상태를 놓친다.
    static var isUsingTestUnits: Bool {
        let values = [Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String]
            + AdSlot.allCases.map(unitID)
        let known = values.compactMap { $0 }
        guard !known.isEmpty else { return true }
        return known.contains { $0.contains(testPublisher) }
    }
}
