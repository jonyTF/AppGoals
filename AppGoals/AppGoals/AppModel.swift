//
//  AppModel.swift
//  AppGoals
//
//  App-wide state: credentials, the cached metrics snapshot, the active goal,
//  and the refresh orchestration that keeps both the app and widgets current.
//

import Foundation
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppModel {
    private(set) var connection: MetricsConnection
    var snapshot: MetricsSnapshot?
    var goal: Goal?

    /// Source for the 28-day revenue metric: real-time endpoint vs overview.
    var useRealtimeRevenue: Bool

    /// Whether today's new-subscriptions count includes resubscriptions on top of
    /// new direct subscriptions.
    var includeResubscriptions: Bool

    var isRefreshing = false
    var lastError: String?

    private let client = MetricsClient()
    private var requestID = UUID()

    init() {
        let connection = MetricsConnection.load()
        self.connection = connection
        snapshot = SnapshotStore.load().flatMap { $0.matches(connection) ? $0 : nil }
        goal = GoalStore.load()

        // Default the real-time revenue source on for first launch.
        if AppGroupConfig.defaults.object(forKey: AppGroupConfig.DefaultsKey.realtimeRevenue) == nil {
            AppGroupConfig.useRealtimeRevenue = true
        }
        useRealtimeRevenue = AppGroupConfig.useRealtimeRevenue
        includeResubscriptions = AppGroupConfig.includeResubscriptions

        #if DEBUG
        if CommandLine.arguments.contains("-seedSuperwallSampleData") {
            seedSampleData(provider: .superwall)
        } else if CommandLine.arguments.contains("-seedSampleData") {
            seedSampleData(provider: .revenueCat)
        }
        #endif
    }

    #if DEBUG
    /// Populates the stores with demo data so the dashboard and widgets can be
    /// exercised without live credentials. Use `-seedSampleData` for RevenueCat
    /// or `-seedSuperwallSampleData` for Superwall.
    private func seedSampleData(provider: MetricsProvider) {
        KeychainStore.saveAPIKey("sk_sample_dev_key", provider: provider)
        connection = MetricsConnection(provider: provider, resourceID: provider == .superwall ? "123" : "demo")
        connection.save()
        var snap = SampleData.snapshot
        snap.provider = provider
        snap.projectID = connection.resourceID
        if provider == .superwall {
            let supported: Set<MetricID> = [.mrr, .revenue, .activeSubscriptions, .newPaidSubscriptions]
            snap.metrics = snap.metrics.filter { $0.metricID.map(supported.contains) ?? false }
        }
        snapshot = snap
        SnapshotStore.save(snap)
        let g = SampleData.goal
        goal = g
        GoalStore.save(g)
        reloadWidgets()
    }
    #endif

    var hasCredentials: Bool {
        KeychainStore.loadAPIKey(provider: connection.provider)?.isEmpty == false &&
        !connection.resourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var metrics: [OverviewMetric] { snapshot?.metrics ?? [] }

    func metric(for id: String) -> OverviewMetric? {
        metrics.first { $0.id == id }
    }

    // MARK: Credentials

    /// Validates the credentials with a live fetch, then persists them on success.
    func saveCredentials(apiKey: String, resourceID: String, provider: MetricsProvider) async -> Bool {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = MetricsConnection(provider: provider,
                                     resourceID: resourceID.trimmingCharacters(in: .whitespacesAndNewlines))
        let request = UUID()
        requestID = request
        isRefreshing = true
        lastError = nil
        defer { if requestID == request { isRefreshing = false } }

        do {
            let metrics = try await client.fetchAllMetrics(connection: next, key: key,
                                                           useRealtimeRevenue: useRealtimeRevenue,
                                                           includeResubscriptions: includeResubscriptions)
            guard requestID == request, !Task.isCancelled else { return false }
            guard KeychainStore.saveAPIKey(key, provider: provider) else {
                lastError = "Couldn't securely store the API key. Please try again."
                return false
            }
            if connection != next {
                if connection.provider != provider {
                    KeychainStore.deleteAPIKey(provider: connection.provider)
                }
                goal = nil
                GoalStore.clear()
            }
            connection = next
            next.save()
            persist(metrics: metrics, connection: next)
            reloadWidgets()
            return true
        } catch {
            guard requestID == request else { return false }
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    // MARK: Refresh

    func refresh() async {
        let connection = connection
        guard let key = KeychainStore.loadAPIKey(provider: connection.provider), !connection.resourceID.isEmpty else {
            lastError = "Connect \(connection.provider.name) in setup first."
            return
        }
        let request = UUID()
        requestID = request
        isRefreshing = true
        lastError = nil
        defer { if requestID == request { isRefreshing = false } }

        do {
            let metrics = try await client.fetchAllMetrics(connection: connection, key: key,
                                                           useRealtimeRevenue: useRealtimeRevenue,
                                                           includeResubscriptions: includeResubscriptions)
            guard requestID == request, self.connection == connection, !Task.isCancelled else { return }
            persist(metrics: metrics, connection: connection)
            reloadWidgets()
        } catch {
            guard requestID == request else { return }
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Switches the revenue source and re-fetches.
    func setRealtimeRevenue(_ enabled: Bool) {
        useRealtimeRevenue = enabled
        AppGroupConfig.useRealtimeRevenue = enabled
        Task { await refresh() }
    }

    /// Toggles whether resubscriptions count toward today's new subscriptions and
    /// re-fetches so the metric reflects the new definition.
    func setIncludeResubscriptions(_ enabled: Bool) {
        includeResubscriptions = enabled
        AppGroupConfig.includeResubscriptions = enabled
        Task { await refresh() }
    }

    // MARK: Goal

    func saveGoal(_ goal: Goal) {
        self.goal = goal
        GoalStore.save(goal)
        reloadWidgets()
    }

    func deleteGoal() {
        goal = nil
        GoalStore.clear()
        reloadWidgets()
    }

    // MARK: Sign out

    func signOut() {
        requestID = UUID()
        isRefreshing = false
        lastError = nil
        KeychainStore.deleteAPIKey(provider: connection.provider)
        SnapshotStore.clear()
        GoalStore.clear()
        MetricsConnection.clear()
        connection = MetricsConnection(provider: .revenueCat, resourceID: "")
        snapshot = nil
        goal = nil
        reloadWidgets()
    }

    // MARK: Helpers

    private func persist(metrics: [OverviewMetric], connection: MetricsConnection) {
        let snap = MetricsSnapshot(metrics: metrics, fetchedAt: Date(), projectID: connection.resourceID,
                                   provider: connection.provider)
        snapshot = snap
        SnapshotStore.save(snap)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
