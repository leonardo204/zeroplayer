import Foundation

/// Info.plist 로 주입된 빌드 설정을 읽는다. 값은 Configs/Base.xcconfig 와
/// 저장소 루트의 Secrets.xcconfig 에서 온다.
enum AppConfig {
    static let proxyBaseURL: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "ZPProxyBaseURL") as? String,
            let url = URL(string: raw.trimmingCharacters(in: .whitespaces))
        else {
            preconditionFailure("ZPProxyBaseURL 이 Info.plist 에 없다. Configs/Base.xcconfig 를 확인한다.")
        }
        return url
    }()

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// radio-browser 가 요구하는 형식. 프록시가 대신 보내지만 앱도 같은 값을 쓴다.
    static var userAgent: String { "zeroplayer/\(appVersion)" }

    /// 서버가 만드는 문구를 어느 말로 받을지. 추천 이유와 알람 알림 본문에 쓴다.
    ///
    /// 앱 화면 문구는 문자열 카탈로그가 맡고, 이 값은 **서버에 보내는 것**이다.
    /// 기기 설정이 아니라 앱이 실제로 고른 번들을 따라가야 화면과 어긋나지 않는다.
    static var serverLanguage: String { AppLanguage.serverLanguage }
}
