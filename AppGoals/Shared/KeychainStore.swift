//
//  KeychainStore.swift
//  AppGoals
//
//  Minimal Keychain wrapper for provider API keys.
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
    private static func baseQuery(provider: MetricsProvider, useAccessGroup: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppGroupConfig.keychainService,
            kSecAttrAccount as String: provider.keychainAccount,
        ]
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = AppGroupConfig.keychainAccessGroup
        }
        return query
    }

    /// Stores (or replaces) the API key. Tries the shared access group first, then
    /// falls back to the app-private keychain. Returns false only if both fail.
    @discardableResult
    static func saveAPIKey(_ key: String, provider: MetricsProvider = .revenueCat) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        return write(data, provider: provider, useAccessGroup: true) || write(data, provider: provider, useAccessGroup: false)
    }

    private static func write(_ data: Data, provider: MetricsProvider, useAccessGroup: Bool) -> Bool {
        var query = baseQuery(provider: provider, useAccessGroup: useAccessGroup)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func loadAPIKey(provider: MetricsProvider = .revenueCat) -> String? {
        read(provider: provider, useAccessGroup: true) ?? read(provider: provider, useAccessGroup: false)
    }

    private static func read(provider: MetricsProvider, useAccessGroup: Bool) -> String? {
        var query = baseQuery(provider: provider, useAccessGroup: useAccessGroup)
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
    static func deleteAPIKey(provider: MetricsProvider = .revenueCat) -> Bool {
        let a = SecItemDelete(baseQuery(provider: provider, useAccessGroup: true) as CFDictionary) == errSecSuccess
        let b = SecItemDelete(baseQuery(provider: provider, useAccessGroup: false) as CFDictionary) == errSecSuccess
        return a || b
    }
}
