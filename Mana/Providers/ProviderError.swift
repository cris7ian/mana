import Foundation

enum ProviderError: Error, Equatable, Sendable, LocalizedError {
    case missingCredential(provider: ProviderID, field: String)
    case authentication(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case transport(String)
    case response(statusCode: Int)
    case malformedResponse
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingCredential(let provider, let field):
            let localizedField = field == "API key" ? String(localized: "API key") : String(localized: "OpenAI sign-in")
            return String(format: String(localized: "Add the %@ in %@ settings."), localizedField, provider.displayName)
        case .authentication: return String(localized: "Authentication failed. Update this provider's credentials in Settings.")
        case .rateLimited(let seconds):
            if let seconds, seconds.isFinite, seconds >= 0, seconds < Double(Int.max) {
                return String(format: String(localized: "Rate limited. Try again in %d seconds."), Int(seconds.rounded(.up)))
            }
            return String(localized: "Rate limited. Mana will retry at the next refresh.")
        case .transport(let message):
            return String(format: String(localized: "Network error: %@. Check your connection and retry."), message)
        case .response(let code):
            return String(format: String(localized: "The provider returned an unexpected response (HTTP %d)."), code)
        case .malformedResponse: return String(localized: "The provider returned data Mana could not read.")
        case .cancelled: return String(localized: "The request was cancelled.")
        }
    }

    static func transportDescription(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return String(localized: "request timed out")
            case .notConnectedToInternet, .networkConnectionLost: return String(localized: "network unavailable")
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return String(localized: "cannot connect to provider")
            case .cancelled: return String(localized: "request cancelled")
            default: return String(localized: "connection failed")
            }
        }
        return String(localized: "connection failed")
    }
}

enum RetryAfterParser {
    static func interval(_ value: String?, now: Date = Date()) -> TimeInterval? {
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
