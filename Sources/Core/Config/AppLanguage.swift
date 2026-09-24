import Foundation
import SwiftUI
import UIKit

/// 앱이 지금 어떤 말로 보이는지, 그리고 그 설정을 어디서 바꾸는지.
///
/// **앱 안에서 직접 바꾸지 않는다.** iOS 는 다국어 앱마다 설정 앱에 언어 항목을
/// 만들어 주고, 거기서 고르면 앱을 다시 열어 주며 곧바로 반영한다. 앱 안에서 바꾸려면
/// `Bundle.main` 의 문자열 조회를 가로채야 하는데 SwiftUI 의 `Text` 에는 통하지 않는다
/// (실제로 해 보고 확인했다). 그래서 설정 화면은 지금 언어를 보여 주고 그 화면으로 보낸다.
enum AppLanguage {
    /// 지금 앱이 실제로 쓰고 있는 언어 코드. 번들이 고른 값이라 화면과 늘 맞는다.
    static var code: String {
        let picked = Bundle.main.preferredLocalizations.first ?? "ko"
        return picked.hasPrefix("ko") ? "ko" : "en"
    }

    /// 설정 화면에 띄우는 이름. 제 나라 말로 적는다.
    static var label: String { code == "ko" ? "한국어" : "English" }

    /// 서버가 만드는 문구(추천 이유·알람 본문)를 받을 말. 화면과 같은 값을 쓴다.
    static var serverLanguage: String { code }

    /// iOS 설정 앱의 이 앱 화면을 연다. 거기에 '언어' 항목이 있다.
    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// 화면을 밝게 볼지 어둡게 볼지.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "기기 설정 따름")
        case .light: return String(localized: "라이트")
        case .dark: return String(localized: "다크")
        }
    }

    /// `nil` 이면 기기 설정을 그대로 따른다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static let storageKey = "zp.theme"
}
