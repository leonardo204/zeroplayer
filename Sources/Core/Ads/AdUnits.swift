import Foundation

/// 광고 단위 ID. 값은 `Configs/Base.xcconfig` 에서 Info.plist 로 주입된다.
///
/// 기본값은 구글이 공개한 테스트 ID 다. AdMob 계정에 앱을 만들기 전에도 배너가 뜨고,
/// 실제 수익 지표와 섞이지 않는다. 실제 단위 ID 는 저장소 루트 `Secrets.xcconfig` 에서 덮어쓴다.
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

    /// 지금 붙어 있는 단위가 구글 테스트 ID 인지. 설정 화면에 그대로 보여 준다.
    static var isUsingTestUnits: Bool {
        let appID = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        return appID?.contains("3940256099942544") ?? true
    }
}
