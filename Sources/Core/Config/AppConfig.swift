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
}
