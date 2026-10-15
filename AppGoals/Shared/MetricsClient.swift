import Foundation

/// Both the app and widget use the same provider routing and metric definitions.
struct MetricsClient {
    var session: URLSession = .shared

    func fetchAllMetrics(connection: MetricsConnection, key: String,
                         useRealtimeRevenue: Bool,
                         includeResubscriptions: Bool) async throws -> [OverviewMetric] {
        switch connection.provider {
        case .revenueCat:
            return try await RevenueCatClient(session: session).fetchAllMetrics(
                projectID: connection.resourceID, key: key,
                useRealtimeRevenue: useRealtimeRevenue,
                includeResubscriptions: includeResubscriptions
            )
        case .superwall:
            return try await SuperwallClient(session: session).fetchAllMetrics(
                applicationID: connection.resourceID, key: key
            )
        }
    }
}
