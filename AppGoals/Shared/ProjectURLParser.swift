//
//  ProjectURLParser.swift
//  AppGoals
//
//  Extracts a RevenueCat project ID from a shared dashboard URL such as
//  https://app.revenuecat.com/projects/c49b113a/api-keys
//

import Foundation

enum ProjectURLParser {
    /// Returns the project ID following `/projects/` in a RevenueCat URL, if any.
    static func projectID(from url: URL?) -> String? {
        guard let url else { return nil }
        guard let host = url.host, host.contains("revenuecat.com") else { return nil }

        let parts = url.pathComponents  // ["/", "projects", "<id>", ...]
        guard let idx = parts.firstIndex(of: "projects"), parts.indices.contains(idx + 1) else {
            return nil
        }
        let candidate = parts[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? nil : candidate
    }

    /// Convenience for share payloads that arrive as plain strings.
    static func projectID(from string: String?) -> String? {
        guard let string, let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return projectID(from: url)
    }
}
