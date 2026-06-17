//
//  SettingsView.swift
//  AppGoals
//
//  Manage the RevenueCat connection and the active goal.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section("RevenueCat") {
                    LabeledContent("Project ID", value: model.projectID)
                    LabeledContent("API key", value: "•••• stored in Keychain")
                }

                Section {
                    Toggle("Real-time revenue", isOn: Binding(
                        get: { model.useRealtimeRevenue },
                        set: { model.setRealtimeRevenue($0) }
                    ))
                } header: {
                    Text("Revenue source")
                } footer: {
                    Text("On: fetch the 28-day revenue from RevenueCat's real-time metrics endpoint (fresher, one extra request). Off: use the value from the overview metrics.")
                }

                Section {
                    Toggle("Include resubscriptions", isOn: Binding(
                        get: { model.includeResubscriptions },
                        set: { model.setIncludeResubscriptions($0) }
                    ))
                } header: {
                    Text("New subscriptions today")
                } footer: {
                    Text("Off: count only new direct subscriptions (no trial or intro offer). On: also include resubscriptions from customers who previously churned.")
                }

                if let goal = model.goal {
                    Section("Goal") {
                        LabeledContent("Tracking", value: goal.metricName)
                        LabeledContent("Target", value: goal.formattedTarget)
                        Button("Delete goal", role: .destructive) {
                            model.deleteGoal()
                        }
                    }
                }

                Section {
                    Button("Disconnect RevenueCat", role: .destructive) {
                        confirmSignOut = true
                    }
                } footer: {
                    Text("Removes the stored API key, project ID, cached metrics, and your goal from this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Disconnect RevenueCat?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) {
                    model.signOut()
                    dismiss()
                }
            } message: {
                Text("You'll need to re-enter your API key and project ID.")
            }
        }
    }
}

#Preview {
    let model = AppModel()
    model.snapshot = SampleData.snapshot
    model.goal = SampleData.goal
    return SettingsView().environment(model)
}
