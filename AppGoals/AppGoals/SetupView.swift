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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var apiKey = ""
    @State private var projectID = ""
    @State private var isWorking = false
    @State private var error: String?

    private let projectsURL = URL(string: "https://app.revenuecat.com/projects")!

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
                    Button {
                        openURL(projectsURL)
                    } label: {
                        Label("Open RevenueCat projects", systemImage: "safari")
                    }
                    Text("Opens RevenueCat in your browser. Pick your project — the code in its URL (`/projects/`**`<id>`**`/…`) is your **Project ID** — then open **API keys** and create a **v2 secret key** with the `charts_metrics:overview:read` permission only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AppGoals")
            .dismissKeyboardSupport()
            .onAppear(perform: consumePendingProjectID)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { consumePendingProjectID() }
            }
        }
    }

    /// Picks up a project ID shared into the app via the Share Extension.
    private func consumePendingProjectID() {
        let defaults = AppGroupConfig.defaults
        guard let pending = defaults.string(forKey: AppGroupConfig.DefaultsKey.pendingProjectID),
              !pending.isEmpty else { return }
        projectID = pending
        defaults.removeObject(forKey: AppGroupConfig.DefaultsKey.pendingProjectID)
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
