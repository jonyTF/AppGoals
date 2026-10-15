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
    /// Today's new subscriptions, shown on home-screen widgets when the goal
    /// tracks a revenue metric. `nil` otherwise (and never shown on lock screen).
    var newSubsToday: Double? = nil
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: Date(), goal: SampleData.goal,
                  current: SampleData.metrics.first { $0.id == "mrr" }?.value ?? 0,
                  hasCredentials: true, newSubsToday: 9)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        completion(makeEntry(allowNetwork: false, snapshot: SnapshotStore.load() ?? SampleData.snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        Task {
            let snapshot = await freshSnapshot()
            let entry = makeEntry(allowNetwork: true, snapshot: snapshot)
            // Ask WidgetKit to rebuild the timeline (and re-fetch) every 15 minutes.
            // iOS budgets background widget refreshes, so it may space these out
            // further under load, but this requests the fastest practical cadence.
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    /// Attempts a live fetch; falls back to the cached snapshot on any failure.
    private func freshSnapshot() async -> MetricsSnapshot? {
        let connection = MetricsConnection.load()
        let cached = SnapshotStore.load().flatMap { $0.matches(connection) ? $0 : nil }
        guard let key = KeychainStore.loadAPIKey(provider: connection.provider),
              !connection.resourceID.isEmpty else { return cached }
        do {
            let metrics = try await MetricsClient().fetchAllMetrics(
                connection: connection, key: key,
                useRealtimeRevenue: AppGroupConfig.useRealtimeRevenue,
                includeResubscriptions: AppGroupConfig.includeResubscriptions
            )
            // A disconnect or provider change may have happened while fetching.
            guard MetricsConnection.load() == connection else { return nil }
            let snap = MetricsSnapshot(metrics: metrics, fetchedAt: Date(), projectID: connection.resourceID,
                                       provider: connection.provider)
            SnapshotStore.save(snap)
            return snap
        } catch {
            return cached
        }
    }

    private func makeEntry(allowNetwork: Bool, snapshot: MetricsSnapshot?) -> GoalEntry {
        let connection = MetricsConnection.load()
        let snapshot = snapshot.flatMap { $0.matches(connection) ? $0 : nil }
        let goal = GoalStore.load()
        let hasCredentials = KeychainStore.loadAPIKey(provider: connection.provider) != nil && !connection.resourceID.isEmpty
        let current = goal.flatMap { g in snapshot?.metric(withID: g.metricID)?.value } ?? goal?.startValue ?? 0
        let newSubsToday: Double? = (goal?.isRevenueGoal == true)
            ? snapshot?.metric(withID: MetricID.newPaidSubscriptions.rawValue)?.value
            : nil
        return GoalEntry(date: Date(), goal: goal, current: current,
                         hasCredentials: hasCredentials, newSubsToday: newSubsToday)
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(goal.metricName)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let n = entry.newSubsToday {
                            Text("+\(Int(n)) new")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Text(OverviewMetric.format(value: entry.current, isCurrency: goal.isCurrency, unit: goal.unit))
                        .font(.title2.bold())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(tint.opacity(0.25))
                            Capsule().fill(tint).frame(width: max(6, geo.size.width * min(1, max(0, progress))))
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                        Spacer(minLength: 0)
                        Text("\(goal.daysRemaining)d")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } else {
                emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // Home screen — medium (mirrors the in-app goal card)
    private var medium: some View {
        Group {
            if let goal = entry.goal {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top) {
                            Text(goal.metricName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            if let n = entry.newSubsToday {
                                Label("\(Int(n)) new today", systemImage: MetricID.newPaidSubscriptions.systemImage)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.background.opacity(0.6), in: .capsule)
                            }
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text(OverviewMetric.format(value: entry.current, isCurrency: goal.isCurrency, unit: goal.unit))
                                .font(.title.bold())
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(tint)
                        }
                    }
                    LabeledProgressBar(
                        progress: progress,
                        startText: OverviewMetric.format(value: goal.startValue, isCurrency: goal.isCurrency, unit: goal.unit),
                        goalText: goal.formattedTarget,
                        tint: tint,
                        barHeight: 10
                    )
                    HStack(spacing: 6) {
                        if let pace {
                            Label(pace.label, systemImage: pace.systemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tint)
                        }
                        Spacer(minLength: 0)
                        Text(goal.daysRemaining == 0 ? "Due today" : "\(goal.daysRemaining)d left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                Text("\(OverviewMetric.format(value: entry.current, isCurrency: goal.isCurrency, unit: goal.unit)) · \(Int((progress * 100).rounded()))%")
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
                    HStack(spacing: 4) {
                        Text(OverviewMetric.format(value: entry.current, isCurrency: goal.isCurrency, unit: goal.unit))
                            .font(.headline).fontWeight(.bold)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let pace {
                            Label("\(goal.daysRemaining)d", systemImage: pace.systemImage)
                                .font(.caption2)
                                .labelStyle(.titleAndIcon)
                                .lineLimit(1)
                        } else {
                            Text("\(goal.daysRemaining)d").font(.caption2)
                        }
                    }
                    HStack(spacing: 6) {
                        Gauge(value: progress) { EmptyView() }
                            .gaugeStyle(.accessoryLinearCapacity)
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.weight(.semibold))
                    }
                    HStack(spacing: 4) {
                        Text(OverviewMetric.format(value: goal.startValue, isCurrency: goal.isCurrency, unit: goal.unit))
                        Spacer(minLength: 0)
                        Text(goal.formattedTarget)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
              hasCredentials: true, newSubsToday: 9)
}
