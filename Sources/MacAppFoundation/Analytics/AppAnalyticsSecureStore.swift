import Foundation
import Security

actor AppAnalyticsSecureStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func string(for account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AppAnalyticsError.storage("Secure analytics installation storage is unavailable.")
        }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw AppAnalyticsError.storage("Secure analytics installation storage is unavailable.")
        }
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = lookup
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AppAnalyticsError.storage("Secure analytics installation storage is unavailable.")
            }
        } else if updateStatus != errSecSuccess {
            throw AppAnalyticsError.storage("Secure analytics installation storage is unavailable.")
        }
    }
}
