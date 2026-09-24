import GoogleMobileAds
import SwiftUI
import os
import UIKit

/// AdMob 배너 하나를 SwiftUI 에 끼워 넣는다.
///
/// 배너는 화면 너비를 꽉 채우는 적응형 크기를 쓴다. 기기와 방향에 맞춰 높이가 정해지므로
/// 고정 높이를 쓰는 것보다 잘린 광고가 덜 나온다.
struct AdBanner: UIViewRepresentable {
    let unitID: String
    let width: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: Self.adSize(width: width))
        // 받아 온 광고가 요청한 너비보다 좁을 때가 있다. 바탕을 비워 두지 않으면
        // 양옆이 검게 남는다.
        view.backgroundColor = .clear
        view.adUnitID = unitID
        view.rootViewController = AdConsent.rootViewController()
        view.delegate = context.coordinator
        view.load(Request())
        context.coordinator.loadedWidth = width
        return view
    }

    func updateUIView(_ view: BannerView, context: Context) {
        // 방향이 바뀌면 크기가 달라진다. 너비가 실제로 달라졌을 때만 다시 받는다 —
        // 화면이 다시 그려질 때마다 요청하면 노출 수가 부풀고 정책 위반이 된다.
        guard abs(context.coordinator.loadedWidth - width) > 1 else { return }
        context.coordinator.loadedWidth = width
        view.adSize = Self.adSize(width: width)
        view.rootViewController = AdConsent.rootViewController()
        view.load(Request())
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 배너가 실제로 들어왔는지 알아야 한다. 실패를 조용히 넘기면
    /// '광고가 없는 화면' 과 '광고를 못 받은 화면' 을 구분할 수 없다.
    final class Coordinator: NSObject, BannerViewDelegate {
        var loadedWidth: CGFloat = 0
        private let log = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "ads")

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            log.info("배너 받음")
            #if DEBUG
            AdConsent.debugDump("배너 받음")
            #endif
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            log.error("배너를 못 받았다: \(error.localizedDescription, privacy: .public)")
            #if DEBUG
            AdConsent.debugDump("배너 실패: \(error.localizedDescription)")
            #endif
        }
    }

    static func adSize(width: CGFloat) -> AdSize {
        currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
    }

    /// 지금 창의 너비. 배너는 가로를 꽉 채운다.
    @MainActor
    static func currentWidth() -> CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow?.bounds.width ?? 320
    }
}

/// 배너를 붙여도 되는 자리인지 판정까지 해 주는 껍데기.
///
/// 화면은 이것만 놓으면 된다. 붙이면 안 되는 자리(`docs/05-ads-policy.md` 5번)나
/// 동의를 받지 못한 상태에서는 아무것도 그리지 않는다.
struct AdBannerSlot: View {
    let slot: AdSlot

    @Environment(AdConsent.self) private var consent

    var body: some View {
        if let unitID = AdUnits.unitID(for: slot), consent.allowsBanner(slot) {
            let width = AdBanner.currentWidth()
            AdBanner(unitID: unitID, width: width)
                .frame(width: width, height: AdBanner.adSize(width: width).size.height)
                .frame(maxWidth: .infinity)
                // 받아 온 광고가 요청한 칸보다 좁으면 남는 자리가 검게 보인다.
                // 화면 바탕색을 깔아 목록과 이어 보이게 한다.
                .background(Color(uiColor: .systemBackground))
                .accessibilityLabel("광고")
        }
    }
}
