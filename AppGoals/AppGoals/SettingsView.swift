//
//  SettingsView.swift
//  AppGoals
//
//  Manage the metrics connection and the active goal.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section(model.connection.provider.name) {
                    LabeledContent(model.connection.provider.resourceLabel, value: model.connection.resourceID)
                    LabeledContent("API key", value: "•••• stored in Keychain")
                }

                if model.connection.provider == .revenueCat {
                    RevenueCatSettingsView()
                } else {
                    Section("Superwall metrics") {
                        Text("Revenue covers the last 28 UTC calendar days, including today, before refunds, taxes and fees. Currency values are in USD.")
                        Text("New Subs Today counts paid subscription starts, including trial conversions and intro offers, using Superwall's UTC day. MRR and active subscriptions use the latest chart values.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                    Button("Disconnect \(model.connection.provider.name)", role: .destructive) {
                        confirmSignOut = true
                    }
                } footer: {
                    Text("Removes the stored API key, connection, cached metrics, and your goal from this device. You can then connect either provider.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Disconnect \(model.connection.provider.name)?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) {
                    model.signOut()
                    dismiss()
                }
            } message: {
                Text("You'll need to re-enter your credentials to reconnect.")
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
