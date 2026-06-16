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
    var projectID: String
    var snapshot: MetricsSnapshot?
    var goal: Goal?

    /// Source for the 28-day revenue metric: real-time endpoint vs overview.
    var useRealtimeRevenue: Bool

    var isRefreshing = false
    var lastError: String?

    private let client = RevenueCatClient()

    init() {
        projectID = AppGroupConfig.defaults.string(forKey: AppGroupConfig.DefaultsKey.projectID) ?? ""
        snapshot = SnapshotStore.load()
        goal = GoalStore.load()

        // Default the real-time revenue source on for first launch.
        if AppGroupConfig.defaults.object(forKey: AppGroupConfig.DefaultsKey.realtimeRevenue) == nil {
            AppGroupConfig.useRealtimeRevenue = true
        }
        useRealtimeRevenue = AppGroupConfig.useRealtimeRevenue

        #if DEBUG
        if CommandLine.arguments.contains("-seedSampleData") {
            seedSampleData()
        }
        #endif
    }

    #if DEBUG
    /// Populates the stores with demo data so the dashboard and widgets can be
    /// exercised without live RevenueCat credentials. Triggered by the
    /// `-seedSampleData` launch argument.
    private func seedSampleData() {
        KeychainStore.saveAPIKey("sk_sample_dev_key")
        projectID = "demo-project"
        AppGroupConfig.defaults.set(projectID, forKey: AppGroupConfig.DefaultsKey.projectID)
        let snap = SampleData.snapshot
        snapshot = snap
        SnapshotStore.save(snap)
        let g = SampleData.goal
        goal = g
        GoalStore.save(g)
        reloadWidgets()
    }
    #endif

    var hasCredentials: Bool {
        KeychainStore.loadAPIKey()?.isEmpty == false && !projectID.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var metrics: [OverviewMetric] { snapshot?.metrics ?? [] }

    func metric(for id: String) -> OverviewMetric? {
        metrics.first { $0.id == id }
    }

    // MARK: Credentials

    /// Validates the credentials with a live fetch, then persists them on success.
    func saveCredentials(apiKey: String, projectID: String) async -> Bool {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        do {
            let metrics = try await client.fetchAllMetrics(projectID: project, key: key, useRealtimeRevenue: useRealtimeRevenue)
            KeychainStore.saveAPIKey(key)
            self.projectID = project
            AppGroupConfig.defaults.set(project, forKey: AppGroupConfig.DefaultsKey.projectID)
            persist(metrics: metrics, projectID: project)
            reloadWidgets()
            return true
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    // MARK: Refresh

    func refresh() async {
        guard let key = KeychainStore.loadAPIKey(), !projectID.isEmpty else {
            lastError = RevenueCatError.missingCredentials.errorDescription
            return
        }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        do {
            let metrics = try await client.fetchAllMetrics(projectID: projectID, key: key, useRealtimeRevenue: useRealtimeRevenue)
            persist(metrics: metrics, projectID: projectID)
            reloadWidgets()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Switches the revenue source and re-fetches.
    func setRealtimeRevenue(_ enabled: Bool) {
        useRealtimeRevenue = enabled
        AppGroupConfig.useRealtimeRevenue = enabled
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
        KeychainStore.deleteAPIKey()
        SnapshotStore.clear()
        GoalStore.clear()
        AppGroupConfig.defaults.removeObject(forKey: AppGroupConfig.DefaultsKey.projectID)
        projectID = ""
        snapshot = nil
        goal = nil
        reloadWidgets()
    }

    // MARK: Helpers

    private func persist(metrics: [OverviewMetric], projectID: String) {
        let snap = MetricsSnapshot(metrics: metrics, fetchedAt: Date(), projectID: projectID)
        snapshot = snap
        SnapshotStore.save(snap)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
