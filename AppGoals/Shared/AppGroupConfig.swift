//
//  AppGroupConfig.swift
//  AppGoals
//
//  Shared constants for data that crosses the app <-> widget boundary.
//

import Foundation

enum AppGroupConfig {
    /// App Group used to share the cached metrics snapshot and the active goal
    /// between the main app and the widget extension.
    static let appGroupID = "group.dev.jonathanliu2.AppGoals"

    /// UserDefaults suite backed by the shared App Group container.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // Keychain identifiers for the RevenueCat secret key.
    static let keychainService = "dev.jonathanliu2.AppGoals"
    static let keychainAccount = "revenuecat-api-key"

    /// Shared keychain access group so the widget can also read the key.
    /// Must match the `keychain-access-groups` entitlement
    /// (`$(AppIdentifierPrefix)dev.jonathanliu2.AppGoals`).
    static let keychainAccessGroup = "3ZB3CDJ3AW.dev.jonathanliu2.AppGoals"

    // Keys inside the shared UserDefaults suite.
    enum DefaultsKey {
        static let snapshot = "metrics.snapshot"
        static let goal = "active.goal"
        static let projectID = "revenuecat.projectID"
    }
}
