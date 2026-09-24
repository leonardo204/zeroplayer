import Foundation
import Observation
import Security

/// 히든 기능 해제 상태. 토큰은 키체인에 둔다.
///
/// 이 토큰은 보안 장치가 아니라 문턱이다(`docs/03-proxy-api.md` 2번). 앱을 뜯으면
/// 해제 엔드포인트 주소가 나오므로 부를 수는 있다. 목적은 두 가지뿐이다 —
/// 채널 목록이 공개 API 응답에 섞여 나가지 않게 하는 것, 해제 기록을 남기는 것.
///
/// `UserDefaults` 가 아니라 키체인에 두는 이유는 설치 UUID 와 같다. 앱을 지우기 전에는
/// 초기화·백업에 덜 흔들린다.
@MainActor
@Observable
final class HiddenAccess {
    /// 해제된 상태인지. 화면은 이 값만 본다.
    private(set) var isUnlocked: Bool

    /// 버전 라벨을 몇 번 눌렀는지. 12번이면 열린다.
    /// 1.x 는 40번이었고 해제 직후 `exit(0)` 으로 앱을 껐다 — 애플이 금지하는 동작이다.
    static let tapsToUnlock = 12

    @ObservationIgnored private static let service = "com.zerolive.cloudRadioN.hidden"
    @ObservationIgnored private static let account = "hidden-token"

    @ObservationIgnored private(set) var token: String?

    init() {
        let saved = Self.read()
        self.token = saved
        self.isUnlocked = saved != nil
    }

    func store(token: String) {
        Self.write(token)
        self.token = token
        isUnlocked = true
    }

    /// 해제를 되돌린다. 기기에서 토큰을 지우고 화면에서 라디오를 감춘다.
    func forget() {
        Self.erase()
        token = nil
        isUnlocked = false
    }

    // MARK: - 키체인

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    private static func write(_ value: String) {
        erase()
        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func erase() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
