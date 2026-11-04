//
//  SetupView.swift
//  AppGoals
//
//  Onboarding: collect provider credentials, validate them
//  with a live fetch, then persist.
//

import SwiftUI

struct SetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var apiKey = ""
    @State private var resourceID = ""
    @State private var provider: MetricsProvider = .revenueCat
    @State private var isWorking = false
    @State private var error: String?

    private var canSubmit: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !resourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
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
                        Text("Connect \(provider.name)")
                            .font(.title2.bold())
                        Text("Connect your metrics to set a revenue goal and track progress — on your home and lock screen too.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Metrics source") {
                    Picker("Provider", selection: $provider) {
                        ForEach(MetricsProvider.allCases) { provider in
                            Text(provider.name).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isWorking)
                }

                Section("Credentials") {
                    SecureField(provider == .revenueCat ? "v2 secret key (sk_...)" : "Organization API key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField(provider.resourceLabel, text: $resourceID)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(provider == .superwall ? .numberPad : .default)
                }
                .disabled(isWorking)

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
                    Button {
                        openURL(provider.dashboardURL)
                    } label: {
                        Label("Open \(provider.name)", systemImage: "safari")
                    }
                    if provider == .revenueCat {
                        Text("Pick your project — the code after /projects/ in its URL is your Project ID. Open API keys and create a v2 secret key with charts_metrics:overview:read and charts_metrics:charts:read permissions.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("In Superwall's organization settings, open API Keys (Access Controls) and create a key with Charts read access for your app's project. Select your app and copy its numeric Application ID from the dashboard URL. The public pk_ SDK key cannot read metrics.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Tracks MRR, 28-day revenue, active paid subscriptions, and today's paid starts. Revenue is in USD. Revenue Tracking must be configured in Superwall.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("AppGoals")
            .dismissKeyboardSupport()
            .onChange(of: provider) {
                apiKey = ""
                resourceID = ""
                error = nil
            }
        }
    }

    private func submit() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        let ok = await model.saveCredentials(apiKey: apiKey, resourceID: resourceID, provider: provider)
        if !ok { error = model.lastError ?? "Couldn't validate those credentials." }
    }
}

#Preview {
    SetupView().environment(AppModel())
}
