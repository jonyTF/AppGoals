//
//  KeychainStore.swift
//  AppGoals
//
//  Minimal Keychain wrapper for the RevenueCat secret key.
//
//  When the shared keychain access group is provisioned (device builds signed by
//  Xcode with the Keychain Sharing capability), the key is stored there so the
//  widget extension can read it and refresh independently. When that entitlement
//  isn't available (e.g. ad-hoc simulator builds), we transparently fall back to
//  the app-private keychain — the app still works; the widget just renders from
//  the cached App Group snapshot instead of fetching on its own.
//

import Foundation
import Security

enum KeychainStore {
    private static func baseQuery(useAccessGroup: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppGroupConfig.keychainService,
            kSecAttrAccount as String: AppGroupConfig.keychainAccount,
        ]
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = AppGroupConfig.keychainAccessGroup
        }
        return query
    }

    /// Stores (or replaces) the API key. Tries the shared access group first, then
    /// falls back to the app-private keychain. Returns false only if both fail.
    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        return write(data, useAccessGroup: true) || write(data, useAccessGroup: false)
    }

    private static func write(_ data: Data, useAccessGroup: Bool) -> Bool {
        var query = baseQuery(useAccessGroup: useAccessGroup)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func loadAPIKey() -> String? {
        read(useAccessGroup: true) ?? read(useAccessGroup: false)
    }

    private static func read(useAccessGroup: Bool) -> String? {
        var query = baseQuery(useAccessGroup: useAccessGroup)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return nil }
        return key
    }

    @discardableResult
    static func deleteAPIKey() -> Bool {
        let a = SecItemDelete(baseQuery(useAccessGroup: true) as CFDictionary) == errSecSuccess
        let b = SecItemDelete(baseQuery(useAccessGroup: false) as CFDictionary) == errSecSuccess
        return a || b
    }
}
