//
//  SampleData.swift
//  AppGoals
//
//  Demo data so SwiftUI previews and widget galleries render without a live
//  RevenueCat account.
//

import Foundation

enum SampleData {
    static let metrics: [OverviewMetric] = [
        OverviewMetric(id: "mrr", name: "MRR", unit: "$", period: "P28D", value: 7_420),
        OverviewMetric(id: "revenue", name: "Revenue", unit: "$", period: "P28D", value: 9_180),
        OverviewMetric(id: "active_subscriptions", name: "Active Subscriptions", unit: "", value: 1_284),
        OverviewMetric(id: "active_trials", name: "Active Trials", unit: "", value: 96),
        OverviewMetric(id: "new_customers", name: "New Customers", unit: "", period: "P28D", value: 213),
        OverviewMetric(id: "active_users", name: "Active Users", unit: "", period: "P28D", value: 5_640),
    ]

    static var snapshot: MetricsSnapshot {
        MetricsSnapshot(metrics: metrics, fetchedAt: Date(timeIntervalSinceNow: -1_800), projectID: "demo")
    }

    static var goal: Goal {
        Goal(
            metricID: "mrr",
            metricName: "MRR",
            isCurrency: true,
            unit: "$",
            targetValue: 10_000,
            startValue: 4_000,
            startDate: Date(timeIntervalSinceNow: -45 * 86_400),
            targetDate: Date(timeIntervalSinceNow: 45 * 86_400)
        )
    }
}
