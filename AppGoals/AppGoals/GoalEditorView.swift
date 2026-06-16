//
//  GoalEditorView.swift
//  AppGoals
//
//  Create or edit the single active goal: pick a metric, a target value, and a
//  deadline. The current metric value is captured as the goal's start value.
//

import SwiftUI

struct GoalEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMetricID: String
    @State private var targetText: String
    @State private var targetDate: Date

    private let existing: Goal?

    init(existing: Goal?, metrics: [OverviewMetric]) {
        self.existing = existing
        _selectedMetricID = State(initialValue: existing?.metricID ?? metrics.first?.id ?? "mrr")
        _targetText = State(initialValue: existing.map { Self.plainNumber($0.targetValue) } ?? "")
        _targetDate = State(initialValue: existing?.targetDate ?? Date(timeIntervalSinceNow: 90 * 86_400))
    }

    private var metrics: [OverviewMetric] { model.metrics }
    private var selectedMetric: OverviewMetric? { metrics.first { $0.id == selectedMetricID } }
    private var targetValue: Double? { Double(targetText.replacingOccurrences(of: ",", with: "")) }

    private var canSave: Bool {
        selectedMetric != nil && (targetValue ?? 0) > 0 && targetDate > Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Metric") {
                    Picker("Track", selection: $selectedMetricID) {
                        ForEach(metrics) { metric in
                            Label(metric.name, systemImage: metric.metricID?.systemImage ?? "chart.bar")
                                .tag(metric.id)
                        }
                    }
                    if let m = selectedMetric {
                        LabeledContent("Current", value: m.formattedValue)
                    }
                }

                Section("Target") {
                    HStack {
                        if selectedMetric?.isCurrency == true {
                            Text(selectedMetric?.unit?.isEmpty == false ? selectedMetric!.unit! : "$")
                                .foregroundStyle(.secondary)
                        }
                        TextField("Goal value", text: $targetText)
                            .keyboardType(.decimalPad)
                    }
                    DatePicker("By", selection: $targetDate, in: Date()..., displayedComponents: .date)
                }

                if let m = selectedMetric, let target = targetValue, target > 0 {
                    Section {
                        let preview = makePreviewGoal(metric: m, target: target)
                        LabeledContent("From", value: m.formattedValue)
                        LabeledContent("To", value: preview.formattedTarget)
                        LabeledContent("Time left", value: "\(preview.daysRemaining) days")
                    } header: {
                        Text("Summary")
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func makePreviewGoal(metric: OverviewMetric, target: Double) -> Goal {
        Goal(
            id: existing?.id ?? UUID(),
            metricID: metric.id,
            metricName: metric.name,
            isCurrency: metric.isCurrency,
            unit: metric.unit,
            targetValue: target,
            startValue: existing?.startValue ?? metric.value,
            startDate: existing?.startDate ?? Date(),
            targetDate: targetDate
        )
    }

    private func save() {
        guard let m = selectedMetric, let target = targetValue else { return }
        model.saveGoal(makePreviewGoal(metric: m, target: target))
        dismiss()
    }

    private static func plainNumber(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}

#Preview {
    GoalEditorView(existing: nil, metrics: SampleData.metrics)
        .environment({
            let m = AppModel()
            m.snapshot = SampleData.snapshot
            return m
        }())
}
