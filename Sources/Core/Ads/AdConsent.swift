import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform
import os

/// 광고를 켜도 되는지 한 곳에서 판정한다.
///
/// 순서가 정해져 있다. 먼저 구글 동의 SDK(UMP)로 그 지역에 필요한 동의를 받고, 그다음
/// 애플 추적 허가(ATT)를 묻고, 마지막에 광고 SDK 를 시작한다. 구글 문서가 요구하는 순서이고,
/// 거꾸로 하면 EEA·영국에서 동의 없이 광고 요청이 나가 계정이 위험해진다.
///
/// 한국 사용자는 UMP 동의 대상이 아니라 아무 창도 뜨지 않고 바로 `canShowAds` 가 참이 된다.
@MainActor
@Observable
final class AdConsent {
    /// 배너를 요청해도 되는 상태인지. 화면은 이 값만 본다.
    private(set) var canShowAds = false
    /// 설정 화면에 '광고 설정' 줄을 보여 줄지. EEA·영국에서만 참이 된다.
    private(set) var privacyOptionsRequired = false
    /// 추적 허가를 물어본 결과. 거부해도 광고는 나가고 개인화만 꺼진다.
    private(set) var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined

    /// 알람으로 앱이 열린 직후에는 배너를 내린다. 기상 직후 광고는 최악이다
    /// (`docs/05-ads-policy.md` 5번). 이 시각이 지나면 다시 붙는다.
    @ObservationIgnored private var alarmQuietUntil: Date?
    /// 알람으로 열린 화면을 광고 없이 두는 시간.
    static let alarmQuietSeconds: TimeInterval = 90

    @ObservationIgnored private var didStart = false
    #if DEBUG
    /// 확인용으로 동의창을 건너뛰었는지. 이때는 동의 없이도 테스트 배너를 그린다.
    @ObservationIgnored private var skippedConsentForDebug = false
    #endif
    @ObservationIgnored private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zeroPlayer", category: "ads")

    /// 앱이 뜰 때 한 번만 부른다.
    func start() async {
        guard !didStart else { return }
        didStart = true

        await requestConsent()
        await requestTracking()
        startSDK()
    }

    /// 알람이 울려 들어왔다. 잠시 배너를 내린다.
    func enterAlarmQuietPeriod() {
        alarmQuietUntil = Date().addingTimeInterval(Self.alarmQuietSeconds)
    }

    /// 이 자리에 배너를 붙여도 되는지. 자리 판정과 동의 상태를 함께 본다.
    func allowsBanner(_ slot: AdSlot) -> Bool {
        guard canShowAds, AdPlacement.allowsBanner(slot) else { return false }
        if let alarmQuietUntil, Date() < alarmQuietUntil { return false }
        return true
    }

    /// 설정 화면의 '광고 설정'. EEA·영국 사용자가 동의를 다시 고를 수 있게 한다.
    func presentPrivacyOptions() async {
        guard let root = Self.rootViewController() else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentForm.presentPrivacyOptionsForm(from: root) { [weak self] error in
                if let error { self?.log.error("광고 설정 창을 못 열었다: \(error.localizedDescription, privacy: .public)") }
                continuation.resume()
            }
        }
        refreshConsentFlags()
    }

    // MARK: - 단계

    private func requestConsent() async {
        let parameters = RequestParameters()
        #if DEBUG
        // 시뮬레이터에서도 동의창을 볼 수 있게 한다. 릴리스 빌드에는 들어가지 않는다.
        let debugSettings = DebugSettings()
        debugSettings.geography = .disabled
        parameters.debugSettings = debugSettings
        #endif

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
                if let error {
                    self?.log.error("동의 정보를 못 받았다: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume()
            }
        }

        #if DEBUG
        // 시뮬레이터에서 배너 배치만 확인할 때 동의창을 건너뛴다.
        // `-ZPSkipConsentForm 1` 로 켠다. 릴리스 빌드에는 들어가지 않는다.
        if UserDefaults.standard.string(forKey: "ZPSkipConsentForm") == "1" {
            log.info("확인용으로 동의창을 건너뛴다")
            skippedConsentForDebug = true
            refreshConsentFlags()
            return
        }
        #endif

        guard let root = Self.rootViewController() else {
            refreshConsentFlags()
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentForm.loadAndPresentIfRequired(from: root) { [weak self] error in
                if let error {
                    self?.log.error("동의창을 못 띄웠다: \(error.localizedDescription, privacy: .public)")
                }
                continuation.resume()
            }
        }
        refreshConsentFlags()
    }

    /// ATT 는 동의창 뒤에 묻는다. 거부해도 광고는 나가고 개인화만 꺼진다.
    private func requestTracking() async {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "ZPSkipConsentForm") == "1" { return }
        #endif
        trackingStatus = ATTrackingManager.trackingAuthorizationStatus
        guard trackingStatus == .notDetermined else { return }
        trackingStatus = await ATTrackingManager.requestTrackingAuthorization()
    }

    private func startSDK() {
        refreshConsentFlags()
        guard canShowAds else {
            log.info("동의를 받지 못해 광고 SDK 를 시작하지 않는다")
            return
        }
        MobileAds.shared.start { [weak self] _ in
            self?.log.info("광고 SDK 시작됨 (테스트 단위: \(AdUnits.isUsingTestUnits))")
            #if DEBUG
            Self.debugDump("SDK 시작됨 · 테스트 단위 \(AdUnits.isUsingTestUnits)")
            #endif
        }
    }

    private func refreshConsentFlags() {
        canShowAds = ConsentInformation.shared.canRequestAds
        #if DEBUG
        // 동의창을 건너뛴 확인용 실행에서는 테스트 배너를 그려 배치를 본다.
        if skippedConsentForDebug, AdUnits.isUsingTestUnits { canShowAds = true }
        #endif
        #if DEBUG
        // 시뮬레이터 로그 스트림이 비어 나오는 맥이 있어 파일로도 남긴다.
        // `xcrun simctl get_app_container <기기> com.zerolive.cloudRadioN data` 밑에서 읽는다.
        Self.debugDump("canRequestAds=\(ConsentInformation.shared.canRequestAds)"
                       + " status=\(ConsentInformation.shared.consentStatus.rawValue)"
                       + " form=\(ConsentInformation.shared.formStatus.rawValue)"
                       + " units=\(AdUnits.unitID(for: .recommendList) ?? "-")")
        #endif
        privacyOptionsRequired =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    #if DEBUG
    /// 확인용 기록. 릴리스 빌드에는 들어가지 않는다.
    static func debugDump(_ line: String) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let url = dir.appendingPathComponent("zp-ads.log")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (text + line + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
    #endif

    // MARK: - 화면 찾기

    /// 동의창을 띄울 화면. SwiftUI 라 직접 들고 있는 뷰 컨트롤러가 없어 장면에서 찾는다.
    static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController
    }
}
