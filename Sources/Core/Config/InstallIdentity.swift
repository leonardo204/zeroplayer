import Foundation
import Security

/// 설치 한 건을 가리키는 UUID. 기기 식별자가 아니다.
///
/// 앱을 지웠다 깔면 새로 만들어진다. 알람 등록과 남용 차단에만 쓰고,
/// 키체인에 두는 이유는 `UserDefaults` 와 달리 백업·초기화에 덜 흔들리기 때문이다.
enum InstallIdentity {
    private static let service = "com.zerolive.cloudRadioN.install"
    private static let account = "install-id"

    static let current: String = {
        if let saved = read() { return saved }
        let fresh = UUID().uuidString
        write(fresh)
        return fresh
    }()

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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
