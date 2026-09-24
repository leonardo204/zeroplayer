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
    /// 지금은 한국어와 영어 둘뿐이라 한국어가 아니면 영어로 본다.
    /// 방송국 이름과 한국 지상파 편성표는 고유명사라 서버가 원문을 그대로 준다.
    static var serverLanguage: String {
        Locale.preferredLanguages.first.map { $0.hasPrefix("ko") ? "ko" : "en" } ?? "ko"
    }
}
