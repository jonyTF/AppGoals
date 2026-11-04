import SwiftUI

struct RevenueCatSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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
    }
}
