//
//  Widget.swift
//  Widget
//
//  Home-screen and lock-screen widget showing progress toward the active goal.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct GoalEntry: TimelineEntry {
    let date: Date
    let goal: Goal?
    let current: Double
    let hasCredentials: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: SampleData.goal,
                  current: SampleData.metrics.first { $0.id == "mrr" }?.value ?? 0,
                  hasCredentials: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        completion(makeEntry(allowNetwork: false, snapshot: SnapshotStore.load() ?? SampleData.snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        Task {
            let snapshot = await freshSnapshot()
            let entry = makeEntry(allowNetwork: true, snapshot: snapshot)
            // Refresh roughly hourly; metrics don't move minute-to-minute.
            let next = Calendar.current.date(byAdding: .minute, value: 60, to: Date()) ?? Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    /// Attempts a live fetch; falls back to the cached snapshot on any failure.
    private func freshSnapshot() async -> MetricsSnapshot? {
        let cached = SnapshotStore.load()
        guard let key = KeychainStore.loadAPIKey() else { return cached }
        let projectID = AppGroupConfig.defaults.string(forKey: AppGroupConfig.DefaultsKey.projectID) ?? cached?.projectID ?? ""
        guard !projectID.isEmpty else { return cached }
        do {
            let metrics = try await RevenueCatClient().fetchOverview(projectID: projectID, key: key)
            let snap = MetricsSnapshot(metrics: metrics, fetchedAt: Date(), projectID: projectID)
            SnapshotStore.save(snap)
            return snap
        } catch {
            return cached
        }
    }

    private func makeEntry(allowNetwork: Bool, snapshot: MetricsSnapshot?) -> GoalEntry {
        let goal = GoalStore.load()
        let hasCredentials = KeychainStore.loadAPIKey() != nil
        let current = goal.flatMap { g in snapshot?.metric(withID: g.metricID)?.value } ?? goal?.startValue ?? 0
        return GoalEntry(date: Date(), goal: goal, current: current, hasCredentials: hasCredentials)
    }
}

// MARK: - Views

struct GoalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: GoalEntry

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var progress: Double { entry.goal?.progressFraction(current: entry.current) ?? 0 }
    private var pace: Goal.PaceStatus? { entry.goal?.paceStatus(current: entry.current, asOf: entry.date) }

    private var tint: Color {
        switch pace {
        case .complete, .ahead: return .green
        case .behind: return .orange
        default: return .accentColor
        }
    }

    // Home screen — small
    private var small: some View {
        Group {
            if let goal = entry.goal {
                VStack(alignment: .leading, spacing: 8) {
                    Label(goal.metricName, systemImage: MetricID(rawValue: goal.metricID)?.systemImage ?? "target")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    ProgressRing(progress: progress, lineWidth: 10, tint: tint)
                        .frame(width: 64, height: 64)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                    Text("\(goal.daysRemaining)d left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // Home screen — medium
    private var medium: some View {
        Group {
            if let goal = entry.goal {
                HStack(spacing: 16) {
                    ProgressRing(progress: progress, lineWidth: 12, tint: tint)
                        .frame(width: 90, height: 90)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(goal.metricName).font(.headline)
                        Text("\(OverviewMetric.format(value: entry.current, isCurrency: goal.isCurrency, unit: goal.unit)) of \(goal.formattedTarget)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let pace { Text(pace.label).font(.caption.weight(.semibold)).foregroundStyle(tint) }
                        Text(goal.daysRemaining == 0 ? "Due today" : "\(goal.daysRemaining) days left")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // Lock screen — circular
    private var circular: some View {
        Gauge(value: progress) {
            Image(systemName: "target")
        } currentValueLabel: {
            Text(progress, format: .percent.precision(.fractionLength(0)))
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.clear, for: .widget)
    }

    // Lock screen — inline
    private var inline: some View {
        Group {
            if let goal = entry.goal {
                Text("\(goal.metricName) \(Int((progress * 100).rounded()))% · \(goal.daysRemaining)d")
            } else {
                Text("Set a goal in AppGoals")
            }
        }
    }

    // Lock screen — rectangular
    private var rectangular: some View {
        Group {
            if let goal = entry.goal {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.metricName).font(.headline)
                    Gauge(value: progress) {
                        EmptyView()
                    } currentValueLabel: {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    Text("\(goal.daysRemaining)d left · \(OverviewMetric.format(value: entry.current, isCurrency: goal.isCurrency, unit: goal.unit))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("Set a goal in AppGoals")
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "target").font(.title)
            Text(entry.hasCredentials ? "Set a goal" : "Open AppGoals")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct GoalProgressWidget: Widget {
    let kind = "GoalProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GoalWidgetView(entry: entry)
        }
        .configurationDisplayName("Goal Progress")
        .description("Track progress toward your RevenueCat goal.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

#Preview(as: .systemMedium) {
    GoalProgressWidget()
} timeline: {
    GoalEntry(date: .now, goal: SampleData.goal,
              current: SampleData.metrics.first { $0.id == "mrr" }!.value,
              hasCredentials: true)
}
