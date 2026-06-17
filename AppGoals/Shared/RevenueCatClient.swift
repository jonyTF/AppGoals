//
//  RevenueCatClient.swift
//  AppGoals
//
//  Thin async client for the RevenueCat REST API v2 metrics endpoints.
//

import Foundation

enum RevenueCatError: LocalizedError {
    case missingCredentials
    case unauthorized
    case rateLimited
    case http(Int)
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Add your RevenueCat API key and project ID first."
        case .unauthorized: return "The API key was rejected. Check that it's a v2 secret key with overview read access."
        case .rateLimited: return "RevenueCat rate limit reached (25/min). Try again shortly."
        case .http(let code): return "RevenueCat returned an unexpected error (HTTP \(code))."
        case .network(let msg): return "Network error: \(msg)"
        case .decoding: return "Couldn't read the metrics response from RevenueCat."
        }
    }
}

/// Revenue definitions supported by the /metrics/revenue endpoint.
enum RevenueType: String {
    case gross = "revenue"               // gross revenue (default)
    case netOfTaxes = "revenue_net_of_taxes"
    case proceeds                        // net of taxes and store commission
}

struct RevenueCatClient {
    var session: URLSession = .shared
    private let baseURL = URL(string: "https://api.revenuecat.com/v2")!

    // MARK: Combined fetch

    /// Fetches the overview metrics. When `useRealtimeRevenue` is set, the 28-day
    /// `revenue` metric is replaced with a fresher value from the dedicated
    /// /metrics/revenue endpoint. Overview is required; if the realtime revenue
    /// call fails, the overview's revenue is kept.
    func fetchAllMetrics(projectID: String, key: String,
                         useRealtimeRevenue: Bool,
                         includeResubscriptions: Bool) async throws -> [OverviewMetric] {
        var metrics = try await fetchOverview(projectID: projectID, key: key)

        // Today's new paid subscriptions come from the charts endpoint, which the
        // overview doesn't cover. Best-effort: if the key lacks the
        // `charts_metrics:charts:read` permission (or the call otherwise fails),
        // the rest of the dashboard still loads without it.
        if let newSubs = try? await fetchNewPaidSubscriptions(projectID: projectID, key: key,
                                                              includeResubscriptions: includeResubscriptions) {
            if let idx = metrics.firstIndex(where: { $0.id == newSubs.id }) {
                metrics[idx] = newSubs
            } else {
                metrics.append(newSubs)
            }
        }

        guard useRealtimeRevenue else { return metrics }

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -28, to: end) ?? end
        if let revenue = try? await fetchRevenue(projectID: projectID, key: key, start: start, end: end) {
            if let idx = metrics.firstIndex(where: { $0.id == revenue.id }) {
                metrics[idx] = revenue
            } else {
                metrics.append(revenue)
            }
        }
        return metrics
    }

    // MARK: Overview metrics

    /// GET /projects/{id}/metrics/overview
    func fetchOverview(projectID: String, key: String) async throws -> [OverviewMetric] {
        let (project, secret) = try credentials(projectID, key)
        let url = baseURL
            .appendingPathComponent("projects").appendingPathComponent(project)
            .appendingPathComponent("metrics").appendingPathComponent("overview")

        let data = try await send(url: url, key: secret)
        do {
            return try JSONDecoder().decode(OverviewResponse.self, from: data).metrics
        } catch {
            throw RevenueCatError.decoding
        }
    }

    // MARK: Revenue metric

    /// GET /projects/{id}/metrics/revenue?start_date=&end_date=&revenue_type=
    /// Returns the total revenue across the date range as a single metric.
    func fetchRevenue(projectID: String, key: String,
                      start: Date, end: Date,
                      type: RevenueType = .gross,
                      currency: String? = nil) async throws -> OverviewMetric {
        let (project, secret) = try credentials(projectID, key)
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("projects").appendingPathComponent(project)
                .appendingPathComponent("metrics").appendingPathComponent("revenue"),
            resolvingAgainstBaseURL: false
        )!
        var items = [
            URLQueryItem(name: "start_date", value: Self.dateFormatter.string(from: start)),
            URLQueryItem(name: "end_date", value: Self.dateFormatter.string(from: end)),
            URLQueryItem(name: "revenue_type", value: type.rawValue),
        ]
        if let currency { items.append(URLQueryItem(name: "currency", value: currency)) }
        components.queryItems = items

        let data = try await send(url: components.url!, key: secret)
        do {
            let revenue = try JSONDecoder().decode(RevenueResponse.self, from: data)
            // Maps onto the same "revenue" metric the overview returns, so it can
            // transparently replace it when the realtime source is selected.
            return OverviewMetric(
                id: MetricID.revenue.rawValue,
                name: "Revenue",
                description: "Last 28 days (real-time)",
                unit: Self.currencySymbol(for: revenue.currency),
                period: "P28D",
                value: revenue.value
            )
        } catch {
            throw RevenueCatError.decoding
        }
    }

    // MARK: New paid subscriptions (charts)

    /// Measures of the `actives_new` chart that make up the value we surface.
    /// "Direct Subscriptions" are brand-new paid subscribers with no trial/intro
    /// offer; "Resubscriptions" are customers who churned and came back.
    private static let directSubsMeasure = "Direct Subscriptions"
    private static let resubsMeasure = "Resubscriptions"

    /// GET /projects/{id}/charts/actives_new?resolution=day&start_date=&end_date=
    /// Returns the count of new paid subscriptions for `day` (defaults to today,
    /// in UTC to match RevenueCat's chart buckets). Counts new direct subscriptions,
    /// optionally adding resubscriptions. Requires the API key to carry the
    /// `charts_metrics:charts:read` permission.
    func fetchNewPaidSubscriptions(projectID: String, key: String,
                                   day: Date = Date(),
                                   includeResubscriptions: Bool) async throws -> OverviewMetric {
        let (project, secret) = try credentials(projectID, key)
        let dayString = Self.dateFormatter.string(from: day)
        var components = URLComponents(
            url: baseURL
                .appendingPathComponent("projects").appendingPathComponent(project)
                .appendingPathComponent("charts").appendingPathComponent("actives_new"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "resolution", value: "day"),
            URLQueryItem(name: "start_date", value: dayString),
            URLQueryItem(name: "end_date", value: dayString),
        ]

        let data = try await send(url: components.url!, key: secret)
        do {
            let chart = try JSONDecoder().decode(ChartDataResponse.self, from: data)
            let direct = chart.total(measureNamed: Self.directSubsMeasure) ?? 0
            let resubs = includeResubscriptions ? (chart.total(measureNamed: Self.resubsMeasure) ?? 0) : 0
            return OverviewMetric(
                id: MetricID.newPaidSubscriptions.rawValue,
                name: "New Subs Today",
                description: includeResubscriptions
                    ? "New direct subscriptions + resubscriptions today"
                    : "New direct subscriptions today",
                unit: "",
                period: "P1D",
                value: direct + resubs
            )
        } catch {
            throw RevenueCatError.decoding
        }
    }

    // MARK: Shared request handling

    private func credentials(_ projectID: String, _ key: String) throws -> (String, String) {
        let project = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !project.isEmpty, !secret.isEmpty else { throw RevenueCatError.missingCredentials }
        return (project, secret)
    }

    private func send(url: URL, key: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RevenueCatError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw RevenueCatError.network("Invalid response")
        }
        switch http.statusCode {
        case 200...299: return data
        case 401, 403: throw RevenueCatError.unauthorized
        case 429: throw RevenueCatError.rateLimited
        default: throw RevenueCatError.http(http.statusCode)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func currencySymbol(for code: String?) -> String {
        switch code?.uppercased() {
        case "USD", nil: return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY", "CNY": return "¥"
        case .some(let other): return other + " "
        }
    }
}

/// Subset of the charts endpoint response we need. `measures` describes each
/// series in order; `values` carries one entry per (cohort, measure) pair, and
/// `summary.total` sums each measure across the requested range.
private struct ChartDataResponse: Decodable {
    struct Measure: Decodable {
        let displayName: String
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
    }
    struct Value: Decodable {
        let measure: Int
        let value: Double
    }
    struct Summary: Decodable {
        let total: [String: Double]
    }

    let measures: [Measure]
    let values: [Value]
    let summary: Summary?

    /// Total for a measure over the requested range. Prefers the server-computed
    /// `summary.total`; falls back to summing the matching `values` entries.
    func total(measureNamed name: String) -> Double? {
        if let total = summary?.total[name] { return total }
        guard let idx = measures.firstIndex(where: { $0.displayName == name }) else { return nil }
        return values.filter { $0.measure == idx }.reduce(0) { $0 + $1.value }
    }
}

/// Top-level `{ "value": ..., "currency": ... }` of the revenue endpoint.
private struct RevenueResponse: Decodable {
    let value: Double
    let currency: String?

    enum CodingKeys: String, CodingKey { case value, currency }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currency = try? c.decode(String.self, forKey: .currency)
        if let d = try? c.decode(Double.self, forKey: .value) {
            value = d
        } else if let s = try? c.decode(String.self, forKey: .value), let d = Double(s) {
            value = d
        } else {
            throw RevenueCatError.decoding
        }
    }
}
