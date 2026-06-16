//
//  AppGoalsApp.swift
//  AppGoals
//
//  Created by Jonathan Liu on 6/16/26.
//

import SwiftUI

@main
struct AppGoalsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasCredentials {
            DashboardView()
        } else {
            SetupView()
        }
    }
}
