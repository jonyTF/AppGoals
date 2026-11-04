import Foundation

enum MetricsProvider: String, Codable, CaseIterable, Identifiable {
    case revenueCat
    case superwall

    var id: String { rawValue }

    var name: String {
        switch self {
        case .revenueCat: return "RevenueCat"
        case .superwall: return "Superwall"
        }
    }

    var resourceLabel: String {
        self == .revenueCat ? "Project ID" : "Application ID"
    }

    var keychainAccount: String {
        switch self {
        case .revenueCat: return "revenuecat-api-key"
        case .superwall: return "superwall-api-key"
        }
    }

    var dashboardURL: URL {
        URL(string: self == .revenueCat ? "https://app.revenuecat.com" : "https://superwall.com/dashboard")!
    }
}
