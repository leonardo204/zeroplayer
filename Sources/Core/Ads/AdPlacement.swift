import Foundation

/// 어느 화면에 배너를 붙일지 한 곳에서 판정한다.
///
/// 배너 자체는 M8 에서 붙인다. 판정을 먼저 떼어 두는 이유는, 화면마다 흩어 놓으면
/// 나중에 한 곳을 빠뜨리기 때문이다. 근거는 `docs/05-ads-policy.md` 다.
enum AdSlot: String, CaseIterable, Sendable {
    case recommendList
    case discoverList
    case presetList
    case statsList
    /// 재생 화면과 미니 플레이어.
    case player
    /// 한국 지상파 관련 화면 전부.
    case hiddenRadio
    /// 알람 알림을 눌러 열린 직후 화면.
    case afterAlarm
}

enum AdPlacement {
    /// 배너를 붙여도 되는 자리인지.
    ///
    /// 재생 화면은 소리를 듣는 자리라 붙이지 않는다. 히든은 비공개 기능이라 수익화 대상이
    /// 아니다. 알람 직후는 방금 깬 사람에게 광고를 들이미는 자리라 붙이지 않는다.
    static func allowsBanner(_ slot: AdSlot) -> Bool {
        switch slot {
        case .recommendList, .discoverList, .presetList, .statsList:
            return true
        case .player, .hiddenRadio, .afterAlarm:
            return false
        }
    }

    /// 탐색 탭은 무엇을 보고 있느냐에 따라 갈린다. 지상파를 보는 동안에는 내린다.
    static func allowsBannerInDiscover(isShowingHidden: Bool) -> Bool {
        isShowingHidden ? allowsBanner(.hiddenRadio) : allowsBanner(.discoverList)
    }
}
