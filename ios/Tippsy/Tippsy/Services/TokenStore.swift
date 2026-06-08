//
//  TokenStore.swift
//  Tippsy
//
//  Securely stores the auth JWT in the iOS Keychain. The Keychain is encrypted
//  at rest and is the correct place for secrets — UserDefaults is not.
//

import Foundation
import Security

enum TokenStore {
    private static let service = "app.tippsy.auth"
    private static let account = "jwt"

    /// Saves (or replaces) the token. Returns true on success.
    @discardableResult
    static func save(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        // Delete any existing item first so we always insert cleanly.
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Reads the stored token, or nil if none.
    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    /// Removes the stored token (logout).
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
