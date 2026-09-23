import Foundation

enum ProviderError: Error, Equatable, Sendable, LocalizedError {
    case missingCredential(provider: ProviderID, field: String)
    case authentication(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case transport(String)
    case response(statusCode: Int)
    case malformedResponse
    case cancelled

    var retryAfter: TimeInterval? {
        if case .rateLimited(let interval) = self { return interval }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .missingCredential(let provider, let field): return "Add the \(field) in \(provider.displayName) settings."
        case .authentication: return "Authentication failed. Update this provider's credentials in Settings."
        case .rateLimited(let seconds):
            if let seconds { return "Rate limited. Try again in \(Int(seconds.rounded(.up))) seconds." }
            return "Rate limited. Mana will retry at the next refresh."
        case .transport(let message): return "Network error: \(message). Check your connection and retry."
        case .response(let code): return "The provider returned an unexpected response (HTTP \(code))."
        case .malformedResponse: return "The provider returned data Mana could not read."
        case .cancelled: return "The request was cancelled."
        }
    }

    static func transportDescription(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return "request timed out"
            case .notConnectedToInternet, .networkConnectionLost: return "network unavailable"
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed: return "cannot connect to provider"
            case .cancelled: return "request cancelled"
            default: return "connection failed"
            }
        }
        return "connection failed"
    }
}

enum RetryAfterParser {
    static func interval(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value), seconds >= 0 { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
