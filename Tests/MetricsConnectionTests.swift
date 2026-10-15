import Foundation
import XCTest
@testable import AppGoalsCore

final class MetricsConnectionTests: XCTestCase {
    func testLegacyConnectionMigrationAndDisconnect() throws {
        let suite = "AppGoalsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("legacy-project", forKey: AppGroupConfig.DefaultsKey.projectID)

        XCTAssertEqual(MetricsConnection.load(from: defaults),
                       MetricsConnection(provider: .revenueCat, resourceID: "legacy-project"))
        let superwall = MetricsConnection(provider: .superwall, resourceID: "123")
        superwall.save(to: defaults)
        XCTAssertEqual(MetricsConnection.load(from: defaults), superwall)
        XCTAssertNil(defaults.string(forKey: AppGroupConfig.DefaultsKey.projectID))

        MetricsConnection.clear(from: defaults)
        XCTAssertEqual(MetricsConnection.load(from: defaults).resourceID, "")
    }

    func testLegacySnapshotAndProviderIsolation() throws {
        let legacy = Data(#"{"metrics":[],"fetchedAt":0,"projectID":"123"}"#.utf8)
        let snapshot = try JSONDecoder().decode(MetricsSnapshot.self, from: legacy)
        XCTAssertEqual(snapshot.provider, .revenueCat)
        XCTAssertTrue(snapshot.matches(MetricsConnection(provider: .revenueCat, resourceID: "123")))
        XCTAssertFalse(snapshot.matches(MetricsConnection(provider: .superwall, resourceID: "123")))
        XCTAssertFalse(snapshot.matches(MetricsConnection(provider: .revenueCat, resourceID: "456")))

        let superwall = MetricsSnapshot(metrics: [], fetchedAt: Date(), projectID: "123", provider: .superwall)
        let restored = try JSONDecoder().decode(MetricsSnapshot.self, from: JSONEncoder().encode(superwall))
        XCTAssertEqual(restored, superwall)
        XCTAssertNotEqual(MetricsProvider.superwall.keychainAccount, MetricsProvider.revenueCat.keychainAccount)
        XCTAssertEqual(MetricsProvider.revenueCat.keychainAccount, "revenuecat-api-key")
    }
}
