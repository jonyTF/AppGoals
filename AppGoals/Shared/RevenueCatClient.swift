//
//  RevenueCatClient.swift
//  AppGoals
//
//  Thin async client for the RevenueCat REST API v2 Overview Metrics endpoint.
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

struct RevenueCatClient {
    var session: URLSession = .shared
    private let baseURL = URL(string: "https://api.revenuecat.com/v2")!

    /// Fetches the overview metrics for a project.
    func fetchOverview(projectID: String, key: String) async throws -> [OverviewMetric] {
        let trimmedProject = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProject.isEmpty, !trimmedKey.isEmpty else {
            throw RevenueCatError.missingCredentials
        }

        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent(trimmedProject)
            .appendingPathComponent("metrics")
            .appendingPathComponent("overview")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
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
        case 200...299:
            break
        case 401, 403:
            throw RevenueCatError.unauthorized
        case 429:
            throw RevenueCatError.rateLimited
        default:
            throw RevenueCatError.http(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(OverviewResponse.self, from: data).metrics
        } catch {
            throw RevenueCatError.decoding
        }
    }
}
