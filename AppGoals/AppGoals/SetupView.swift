//
//  SetupView.swift
//  AppGoals
//
//  Onboarding: collect the RevenueCat v2 secret key + project ID, validate them
//  with a live fetch, then persist.
//

import SwiftUI

struct SetupView: View {
    @Environment(AppModel.self) private var model

    @State private var apiKey = ""
    @State private var projectID = ""
    @State private var isWorking = false
    @State private var error: String?

    private var canSubmit: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty &&
        !projectID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "target")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        Text("Connect RevenueCat")
                            .font(.title2.bold())
                        Text("AppGoals reads your project's overview metrics so you can set a revenue goal and track progress — on your home and lock screen too.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Credentials") {
                    SecureField("v2 secret key (sk_...)", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Project ID", text: $projectID)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isWorking { ProgressView().controlSize(.small) }
                            Text(isWorking ? "Validating…" : "Test & Save")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                }

                Section("How to get these") {
                    Link(destination: URL(string: "https://app.revenuecat.com/settings/api-keys")!) {
                        Label("Open RevenueCat API keys", systemImage: "key.fill")
                    }
                    Text("Create a **v2 secret key** with the `charts_metrics:overview:read` permission only. Find the **Project ID** in RevenueCat → Project settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AppGoals")
        }
    }

    private func submit() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        let ok = await model.saveCredentials(apiKey: apiKey, projectID: projectID)
        if !ok { error = model.lastError ?? "Couldn't validate those credentials." }
    }
}

#Preview {
    SetupView().environment(AppModel())
}
