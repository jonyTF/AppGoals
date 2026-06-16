//
//  DashboardView.swift
//  AppGoals
//
//  Main screen: the active goal's progress plus a grid of all current metrics.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    @State private var showingGoalEditor = false
    @State private var showingSettings = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    goalSection
                    metricsSection
                    if let updated = model.snapshot?.fetchedAt {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let error = model.lastError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("AppGoals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await model.refresh() } } label: {
                        if model.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isRefreshing)
                }
            }
            .refreshable { await model.refresh() }
            .sheet(isPresented: $showingGoalEditor) {
                GoalEditorView(existing: model.goal, metrics: model.metrics)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                if model.snapshot == nil { await model.refresh() }
            }
        }
    }

    // MARK: Goal

    @ViewBuilder
    private var goalSection: some View {
        if let goal = model.goal {
            GoalCard(goal: goal, current: model.metric(for: goal.metricID)?.value ?? goal.startValue)
                .onTapGesture { showingGoalEditor = true }
        } else {
            Button { showingGoalEditor = true } label: {
                VStack(spacing: 8) {
                    Image(systemName: "target").font(.largeTitle)
                    Text("Set your goal").font(.headline)
                    Text("Pick a metric and a target to start tracking.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Metrics grid

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if model.metrics.isEmpty {
                ContentUnavailableView("No metrics yet", systemImage: "chart.bar",
                                       description: Text("Pull to refresh to load your RevenueCat metrics."))
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.metrics) { metric in
                        MetricTile(metric: metric)
                    }
                }
            }
        }
    }
}

// MARK: - Goal card

struct GoalCard: View {
    let goal: Goal
    let current: Double

    private var progress: Double { goal.progressFraction(current: current) }
    private var pace: Goal.PaceStatus { goal.paceStatus(current: current, asOf: Date()) }

    private var tint: Color {
        switch pace {
        case .complete, .ahead: return .green
        case .onTrack: return .accentColor
        case .behind: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.metricName)
                        .font(.headline)
                    Text("\(OverviewMetric.format(value: current, isCurrency: goal.isCurrency, unit: goal.unit)) of \(goal.formattedTarget)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            LabeledProgressBar(
                progress: progress,
                startText: OverviewMetric.format(value: goal.startValue, isCurrency: goal.isCurrency, unit: goal.unit),
                goalText: goal.formattedTarget,
                tint: tint,
                barHeight: 12
            )

            HStack(spacing: 6) {
                Label(pace.label, systemImage: pace.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
                Text(goal.daysRemaining == 0 ? "Due today" : "\(goal.daysRemaining) days left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 20))
    }
}

// MARK: - Metric tile

struct MetricTile: View {
    let metric: OverviewMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(metric.name, systemImage: metric.metricID?.systemImage ?? "chart.bar")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(metric.formattedValue)
                .font(.title2.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
    }
}

#Preview {
    let model = AppModel()
    model.snapshot = SampleData.snapshot
    model.goal = SampleData.goal
    return DashboardView().environment(model)
}
