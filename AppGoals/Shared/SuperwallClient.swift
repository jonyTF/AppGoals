import Foundation

/// Superwall Charts V2: https://api.superwall.com/docs
/// Requires an organization API key with charts:read access, not a public SDK key.
struct SuperwallClient {
    var session: URLSession = .shared

    func fetchAllMetrics(applicationID: String, key: String,
                         now: Date = Date()) async throws -> [OverviewMetric] {
        let application = applicationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !application.isEmpty, !secret.isEmpty else { throw SuperwallError.missingCredentials }
        guard application.allSatisfy({ $0.isASCII && $0.isNumber }),
              let numericID = UInt64(application), numericID > 0 else {
            throw SuperwallError.invalidApplicationID
        }
        guard !secret.hasPrefix("pk_") else { throw SuperwallError.publicKey }

        // Use UTC calendar days, including today, for a consistent 28-day window.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -27, to: today)!
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone

        let recurring = try await fetchChart(application: application, key: secret,
                                             metric: "mrr", dimension: "mrrDate",
                                             include: ["subscribers"])
        let revenue = try await fetchChart(application: application, key: secret,
                                           metric: "grossRevenue", dimension: "purchaseDate",
                                           range: ["from": formatter.string(from: start),
                                                   "to": formatter.string(from: now)])
        let subscriptions = try await fetchChart(application: application, key: secret,
                                                 metric: "subStarts", dimension: "firstPurchaseDate")

        // MRR and subscribers are point-in-time values; never sum their daily buckets.
        return [
            OverviewMetric(id: MetricID.mrr.rawValue, name: "MRR",
                           description: "Monthly recurring revenue (USD)", unit: "$",
                           value: try recurring.latestValue(metric: "mrr")),
            OverviewMetric(id: MetricID.revenue.rawValue, name: "Revenue",
                           description: "Last 28 days, before refunds, taxes and fees (USD)",
                           unit: "$", period: "P28D", value: try revenue.total(metric: "grossRevenue")),
            OverviewMetric(id: MetricID.activeSubscriptions.rawValue, name: "Active Subscriptions",
                           description: "Active paid subscriptions", unit: "",
                           value: try recurring.latestValue(metric: "mrr", extra: "subscribers")),
            OverviewMetric(id: MetricID.newPaidSubscriptions.rawValue, name: "New Subs Today",
                           description: "Paid starts today (UTC), including trial conversions and intro offers",
                           unit: "", period: "P1D", value: try subscriptions.total(metric: "subStarts")),
        ]
    }

    private func fetchChart(application: String, key: String, metric: String,
                            dimension: String, include: [String] = [],
                            range: [String: String]? = nil) async throws -> SuperwallChartResponse {
        var dateFilter: [String: Any] = ["dimension": dimension, "preset": range == nil ? "today" : "custom"]
        if let range { dateFilter["range"] = range }
        let body: [String: Any] = [
            "application_id": application,
            "y_axis": metric,
            "x_axis": dimension,
            "date_filter": dateFilter,
            "date_interval": "day",
            "environment": ["PRODUCTION"],
            "include": include,
        ]
        var request = URLRequest(url: URL(string: "https://api.superwall.com/v2/charts/data")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw SuperwallError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw SuperwallError.network("Invalid response")
        }
        switch http.statusCode {
        case 200...299: break
        case 401: throw SuperwallError.unauthorized
        case 403: throw SuperwallError.forbidden
        case 404: throw SuperwallError.notFound
        case 429: throw SuperwallError.rateLimited
        default: throw SuperwallError.http(http.statusCode)
        }
        do {
            let chart = try JSONDecoder().decode(SuperwallChartResponse.self, from: data)
            guard chart.yAxis.key == metric else { throw SuperwallError.decoding }
            return chart
        } catch {
            throw SuperwallError.decoding
        }
    }
}
