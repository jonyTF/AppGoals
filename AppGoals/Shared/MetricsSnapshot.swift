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
    var provider: MetricsProvider = .revenueCat

    init(metrics: [OverviewMetric], fetchedAt: Date, projectID: String,
         provider: MetricsProvider = .revenueCat) {
        self.metrics = metrics
        self.fetchedAt = fetchedAt
        self.projectID = projectID
        self.provider = provider
    }

    enum CodingKeys: String, CodingKey {
        case metrics, fetchedAt, projectID, provider
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        metrics = try values.decode([OverviewMetric].self, forKey: .metrics)
        fetchedAt = try values.decode(Date.self, forKey: .fetchedAt)
        projectID = try values.decode(String.self, forKey: .projectID)
        provider = try values.decodeIfPresent(MetricsProvider.self, forKey: .provider) ?? .revenueCat
    }

    func matches(_ connection: MetricsConnection) -> Bool {
        provider == connection.provider && projectID == connection.resourceID
    }

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
