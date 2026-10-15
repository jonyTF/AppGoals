import Foundation
import XCTest
@testable import AppGoalsCore

final class SuperwallClientTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        StubURLProtocol.handler = nil
    }

    func testRequestsAndMetricSemantics() async throws {
        var requests: [[String: Any]] = []
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.superwall.com/v2/charts/data")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try Self.body(of: request)
            requests.append(body)
            XCTAssertEqual(body["application_id"] as? String, "123")
            XCTAssertEqual(body["environment"] as? [String], ["PRODUCTION"])
            let metric = try XCTUnwrap(body["y_axis"] as? String)
            let filter = try XCTUnwrap(body["date_filter"] as? [String: Any])
            switch metric {
            case "mrr":
                XCTAssertEqual(body["include"] as? [String], ["subscribers"])
                XCTAssertEqual(body["x_axis"] as? String, "mrrDate")
                XCTAssertEqual(filter["preset"] as? String, "today")
                // Deliberately unordered buckets: select the latest, never sum MRR.
                return (200, Self.chart(metric, points: [
                    Self.point(metric, date: "2026-10-15T00:00:00", value: 1200, extra: ["subscribers": 42]),
                    Self.point(metric, date: "2026-10-14T00:00:00", value: 1000, extra: ["subscribers": 40])
                ]))
            case "grossRevenue":
                XCTAssertEqual(body["x_axis"] as? String, "purchaseDate")
                XCTAssertEqual(filter["preset"] as? String, "custom")
                let range = try XCTUnwrap(filter["range"] as? [String: String])
                XCTAssertEqual(range["from"], "2026-09-18T00:00:00Z")
                XCTAssertEqual(range["to"], "2026-10-15T12:00:00Z")
                return (200, Self.chart(metric, points: [
                    Self.point(metric, value: 100.25), Self.point(metric, value: 50.50)
                ]))
            case "subStarts":
                XCTAssertEqual(body["x_axis"] as? String, "firstPurchaseDate")
                XCTAssertEqual(filter["preset"] as? String, "today")
                return (200, Self.chart(metric, points: [Self.point(metric, value: 7)]))
            default:
                XCTFail("Unexpected metric \(metric)")
                return (500, Data())
            }
        }
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z"))
        let metrics = try await SuperwallClient(session: session).fetchAllMetrics(
            applicationID: " 123\n", key: " test-secret\n", now: date
        )
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(metrics.map(\.id), ["mrr", "revenue", "active_subscriptions", "new_paid_subscriptions"])
        XCTAssertEqual(metrics.map(\.value), [1200, 150.75, 42, 7])
        XCTAssertEqual(metrics[1].period, "P28D")
        XCTAssertEqual(metrics[3].period, "P1D")
    }

    func testEmptyChartsRepresentNoActivity() async throws {
        StubURLProtocol.handler = { request in
            let metric = try XCTUnwrap(Self.body(of: request)["y_axis"] as? String)
            return (200, Self.chart(metric, points: []))
        }
        let metrics = try await SuperwallClient(session: session).fetchAllMetrics(applicationID: "123", key: "test")
        XCTAssertEqual(metrics.map(\.value), [0, 0, 0, 0])
    }

    func testMissingSeriesOrSubscriberValueIsNotSilentlyZero() throws {
        for points in [[Self.point("different", value: 100)], [Self.point("mrr", value: 100)]] {
            let response = try JSONDecoder().decode(SuperwallChartResponse.self, from: Self.chart("mrr", points: points))
            XCTAssertThrowsError(try response.latestValue(metric: "mrr", extra: "subscribers"))
        }
    }

    func testMalformedAndMismatchedChartsFail() async {
        for data in [Data("{}".utf8), Self.chart("wrongMetric", points: [])] {
            StubURLProtocol.handler = { _ in (200, data) }
            do {
                _ = try await SuperwallClient(session: session).fetchAllMetrics(applicationID: "123", key: "test")
                XCTFail("Malformed charts must fail")
            } catch {
                guard case SuperwallError.decoding = error else { return XCTFail("Unexpected error: \(error)") }
            }
        }
    }

    func testHTTPFailuresAreActionable() async {
        for status in [401, 403, 404, 429, 500] {
            StubURLProtocol.handler = { _ in (status, Data()) }
            do {
                _ = try await SuperwallClient(session: session).fetchAllMetrics(applicationID: "123", key: "test")
                XCTFail("HTTP \(status) must fail")
            } catch let error as SuperwallError {
                switch (status, error) {
                case (401, .unauthorized), (403, .forbidden), (404, .notFound),
                     (429, .rateLimited), (500, .http(500)): break
                default: XCTFail("Unexpected error: \(error)")
                }
            } catch { XCTFail("Unexpected error: \(error)") }
        }
    }

    func testInvalidCredentialsNeverReachNetwork() async {
        StubURLProtocol.handler = { _ in
            XCTFail("Invalid credentials must be rejected locally")
            return (500, Data())
        }
        for (application, key) in [("", "test"), ("123", ""), ("abc", "test"),
                                    ("0", "test"), ("12/3", "test"), ("123", "pk_public")] {
            do {
                _ = try await SuperwallClient(session: session).fetchAllMetrics(applicationID: application, key: key)
                XCTFail("Invalid credentials accepted")
            } catch { XCTAssertTrue(error is SuperwallError) }
        }
    }

    func testRevenueCatRoutingRemainsAvailable() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "api.revenuecat.com")
            XCTAssertEqual(request.httpMethod, "GET")
            if request.url?.path.hasSuffix("overview") == true {
                return (200, Data(#"{"metrics":[{"id":"mrr","name":"MRR","value":123}]}"#.utf8))
            }
            return (403, Data()) // Optional new-subscription chart may be unavailable.
        }
        let metrics = try await MetricsClient(session: session).fetchAllMetrics(
            connection: MetricsConnection(provider: .revenueCat, resourceID: "legacy"),
            key: "test", useRealtimeRevenue: false, includeResubscriptions: false
        )
        XCTAssertEqual(metrics.first?.value, 123)
    }

    private static func body(of request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func point(_ metric: String, date: String = "2026-10-15T00:00:00",
                              value: Double, extra: [String: Double] = [:]) -> [String: Any] {
        ["x": date, "incomplete": true, "values": [metric: ["y": value, "extra": extra]]]
    }

    private static func chart(_ metric: String, points: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["object": "chart_data", "y_axis": ["key": metric], "data": points])
    }
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
