//
//  MetricsSnapshot.swift
//  AppGoals
//
//  Cached copy of the last successful metrics fetch, shared via the App Group
//  so the widget (and the app at launch) can render instantly without a network
//  round-trip.
//

import Foundation

struct MetricsSnapshot: Codable, Hashable {
    var metrics: [OverviewMetric]
    var fetchedAt: Date
    var projectID: String

    func metric(withID id: String) -> OverviewMetric? {
        metrics.first { $0.id == id }
    }
}

enum SnapshotStore {
    static func load() -> MetricsSnapshot? {
        guard let data = AppGroupConfig.defaults.data(forKey: AppGroupConfig.DefaultsKey.snapshot) else {
            return nil
        }
        return try? JSONDecoder().decode(MetricsSnapshot.self, from: data)
    }

    static func save(_ snapshot: MetricsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroupConfig.defaults.set(data, forKey: AppGroupConfig.DefaultsKey.snapshot)
    }

    static func clear() {
        AppGroupConfig.defaults.removeObject(forKey: AppGroupConfig.DefaultsKey.snapshot)
    }
}
