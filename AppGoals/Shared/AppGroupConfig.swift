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
    static let appGroupID = "group.dev.jonathanliu.AppGoals"

    /// UserDefaults suite backed by the shared App Group container.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // Keychain identifiers for the RevenueCat secret key.
    static let keychainService = "dev.jonathanliu.AppGoals"
    static let keychainAccount = "revenuecat-api-key"

    /// Shared keychain access group so the widget can also read the key.
    /// Must match the `keychain-access-groups` entitlement
    /// (`$(AppIdentifierPrefix)dev.jonathanliu.AppGoals`), where the prefix is the
    /// development team ID.
    static let keychainAccessGroup = "PUXGM4N3QJ.dev.jonathanliu.AppGoals"

    // Keys inside the shared UserDefaults suite.
    enum DefaultsKey {
        static let snapshot = "metrics.snapshot"
        static let goal = "active.goal"
        static let projectID = "revenuecat.projectID"
        /// When true, fetch the 28-day revenue from the real-time /metrics/revenue
        /// endpoint instead of using the overview metric.
        static let realtimeRevenue = "revenue.realtime"
        /// When true, today's new-subscriptions count includes resubscriptions on
        /// top of new direct subscriptions. Default (false) is direct only.
        static let includeResubscriptions = "newsubs.includeResubscriptions"
    }

    /// Whether to source 28-day revenue from the real-time endpoint. Read by both
    /// the app and the widget so they stay consistent.
    static var useRealtimeRevenue: Bool {
        get { defaults.bool(forKey: DefaultsKey.realtimeRevenue) }
        set { defaults.set(newValue, forKey: DefaultsKey.realtimeRevenue) }
    }

    /// Whether today's new-subscriptions count includes resubscriptions in
    /// addition to new direct subscriptions. Read by both the app and the widget.
    static var includeResubscriptions: Bool {
        get { defaults.bool(forKey: DefaultsKey.includeResubscriptions) }
        set { defaults.set(newValue, forKey: DefaultsKey.includeResubscriptions) }
    }
}
