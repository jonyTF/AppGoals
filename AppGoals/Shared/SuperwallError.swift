import Foundation

enum SuperwallError: LocalizedError {
    case missingCredentials
    case invalidApplicationID
    case publicKey
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case http(Int)
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Add your Superwall organization API key and application ID first."
        case .invalidApplicationID: return "Enter the numeric application ID from your Superwall dashboard URL."
        case .publicKey: return "Use a Superwall organization API key with charts:read access. Public SDK keys (pk_…) cannot read metrics."
        case .unauthorized: return "Superwall rejected the API key. Check that it hasn't expired or been revoked."
        case .forbidden: return "This Superwall key needs charts:read access to the selected application."
        case .notFound: return "Superwall couldn't find that application. Check its application ID and the key's project access."
        case .rateLimited: return "Superwall rate limit reached. Try again shortly."
        case .http(let code): return "Superwall returned an unexpected error (HTTP \(code))."
        case .network(let message): return "Network error: \(message)"
        case .decoding: return "Couldn't read the metrics response from Superwall."
        }
    }
}
