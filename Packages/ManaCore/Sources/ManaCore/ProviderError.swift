import Foundation

public enum ProviderError: Error, Equatable, Sendable, LocalizedError {
    case missingCredential(provider: ProviderID, field: String)
    case authentication(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case transport(String)
    case response(statusCode: Int)
    case malformedResponse
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .missingCredential(let provider, let field):
            let localizedField = UsageLocalization.text(field)
            return String(format: String(localized: "Add the %@ in %@ settings.", bundle: .module), localizedField, provider.displayName)
        case .authentication: return String(localized: "Authentication failed. Update this provider's credentials in Settings.", bundle: .module)
        case .rateLimited(let seconds):
            if let seconds, seconds.isFinite, seconds >= 0, seconds < Double(Int.max) {
                return String(format: String(localized: "Rate limited. Try again in %lld seconds.", bundle: .module), Int64(seconds.rounded(.up)))
            }
            return String(localized: "Rate limited. Mana will retry at the next refresh.", bundle: .module)
        case .transport(let message):
            return String(format: String(localized: "Network error: %@. Check your connection and retry.", bundle: .module), message)
        case .response(let code):
            return String(format: String(localized: "The provider returned an unexpected response (HTTP %d).", bundle: .module), code)
        case .malformedResponse: return String(localized: "The provider returned data Mana could not read.", bundle: .module)
        case .cancelled: return String(localized: "The request was cancelled.", bundle: .module)
        }
    }

    public static func transportDescription(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return String(localized: "request timed out", bundle: .module)
            case .notConnectedToInternet, .networkConnectionLost: return String(localized: "network unavailable", bundle: .module)
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return String(localized: "cannot connect to provider", bundle: .module)
            case .cancelled: return String(localized: "request cancelled", bundle: .module)
            default: return String(localized: "connection failed", bundle: .module)
            }
        }
        return String(localized: "connection failed", bundle: .module)
    }
}

public enum RetryAfterParser {
    public static func interval(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0,
           seconds < Double(Int.max) { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
