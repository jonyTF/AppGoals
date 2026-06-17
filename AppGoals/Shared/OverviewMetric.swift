//
//  OverviewMetric.swift
//  AppGoals
//
//  Models the RevenueCat v2 Overview Metrics response:
//  GET /v2/projects/{project_id}/metrics/overview
//

import Foundation

/// Known metric ids returned by the overview endpoint. `.other` keeps decoding
/// resilient if RevenueCat adds or renames metrics.
enum MetricID: String, Codable, CaseIterable, Hashable {
    case mrr
    case revenue
    case activeSubscriptions = "active_subscriptions"
    case activeTrials = "active_trials"
    case newCustomers = "new_customers"
    case activeUsers = "active_users"
    case newPaidSubscriptions = "new_paid_subscriptions"

    var fallbackName: String {
        switch self {
        case .mrr: return "MRR"
        case .revenue: return "Revenue"
        case .activeSubscriptions: return "Active Subscriptions"
        case .activeTrials: return "Active Trials"
        case .newCustomers: return "New Customers"
        case .activeUsers: return "Active Users"
        case .newPaidSubscriptions: return "New Subs Today"
        }
    }

    var systemImage: String {
        switch self {
        case .mrr: return "chart.line.uptrend.xyaxis"
        case .revenue: return "dollarsign.circle"
        case .activeSubscriptions: return "person.2.fill"
        case .activeTrials: return "hourglass"
        case .newCustomers: return "person.badge.plus"
        case .activeUsers: return "person.3.fill"
        case .newPaidSubscriptions: return "cart.badge.plus"
        }
    }

    /// Whether the value should be rendered as currency (vs a plain count).
    var isCurrency: Bool {
        self == .mrr || self == .revenue
    }
}

/// A single metric from the overview response.
struct OverviewMetric: Codable, Identifiable, Hashable {
    let id: String          // e.g. "mrr"
    let name: String        // e.g. "MRR"
    let description: String?
    let unit: String?       // e.g. "$" for currency, "" for counts
    let period: String?     // ISO-8601 duration, e.g. "P28D"
    let value: Double

    enum CodingKeys: String, CodingKey {
        case id, name, description, unit, period, value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? id
        description = try? c.decode(String.self, forKey: .description)
        unit = try? c.decode(String.self, forKey: .unit)
        period = try? c.decode(String.self, forKey: .period)
        // RevenueCat may send the value as a number or, defensively, a string.
        if let d = try? c.decode(Double.self, forKey: .value) {
            value = d
        } else if let s = try? c.decode(String.self, forKey: .value), let d = Double(s) {
            value = d
        } else {
            value = 0
        }
    }

    init(id: String, name: String, description: String? = nil, unit: String? = nil,
         period: String? = nil, value: Double) {
        self.id = id
        self.name = name
        self.description = description
        self.unit = unit
        self.period = period
        self.value = value
    }

    var metricID: MetricID? { MetricID(rawValue: id) }

    var isCurrency: Bool {
        metricID?.isCurrency ?? (unit.map { $0.contains("$") || $0.contains("€") || $0.contains("£") } ?? false)
    }

    /// Human-facing formatted value, honoring currency vs count.
    var formattedValue: String { Self.format(value: value, isCurrency: isCurrency, unit: unit) }

    static func format(value: Double, isCurrency: Bool, unit: String?) -> String {
        if isCurrency {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencySymbol = (unit?.isEmpty == false ? unit : "$")
            f.maximumFractionDigits = (abs(value) >= 100 || value.rounded() == value) ? 0 : 2
            return f.string(from: NSNumber(value: value)) ?? "\(unit ?? "$")\(Int(value))"
        } else {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        }
    }
}

/// Wrapper for the top-level `{ "metrics": [...] }` response.
struct OverviewResponse: Decodable {
    let metrics: [OverviewMetric]
}
