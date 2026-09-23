import Foundation
import CoreFoundation

struct CodexUsageDecoder {
    static func decode(_ data: Data, now: Date = Date()) throws -> ProviderSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = root["rate_limit"] as? [String: Any] else {
            throw ProviderError.malformedResponse
        }
        let keys = ["primary_window", "secondary_window"]
        let windows = keys.enumerated().map { index, key -> UsageWindow in
            guard let object = rateLimit[key] as? [String: Any] else {
                return UsageWindow(id: key, label: "window \(index + 1)", content: .missing, resetAt: nil, resetText: nil)
            }
            let label = windowLabel(object["limit_window_seconds"], fallback: "window \(index + 1)")
            let percent = number(object["used_percent"])
            let reset = epochDate(object["reset_at"])
            return UsageWindow(id: key, label: label,
                               content: percent.map { .percent($0) } ?? .unknownPercent,
                               resetAt: reset.date, resetText: reset.text)
        }
        let allowed = rateLimit["allowed"] as? Bool
        return ProviderSnapshot(provider: .codex, windows: windows,
                                isBlocked: allowed == false,
                                blockedReason: allowed == false ? "Requests are currently blocked by a rate limit." : nil,
                                receivedAt: now)
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let result = number.doubleValue
        return result.isFinite ? result : nil
    }

    private static func windowLabel(_ value: Any?, fallback: String) -> String {
        guard let seconds = number(value), seconds > 0 else { return fallback }
        if seconds.truncatingRemainder(dividingBy: 604_800) == 0 { return "\(Int(seconds / 604_800))w" }
        if seconds.truncatingRemainder(dividingBy: 86_400) == 0 { return "\(Int(seconds / 86_400))d" }
        if seconds.truncatingRemainder(dividingBy: 3_600) == 0 { return "\(Int(seconds / 3_600))h" }
        return "\(Int(seconds / 60))m"
    }

    private static func epochDate(_ value: Any?) -> (date: Date?, text: String?) {
        guard let value else { return (nil, nil) }
        if let seconds = number(value) {
            let normalized = seconds > 10_000_000_000 ? seconds / 1_000 : seconds
            let date = Date(timeIntervalSince1970: normalized)
            guard date.timeIntervalSince1970.isFinite, abs(normalized) < 253_402_300_800 else {
                return (nil, String(describing: value))
            }
            return (date, nil)
        }
        if let text = value as? String {
            if let seconds = Double(text) {
                let normalized = seconds > 10_000_000_000 ? seconds / 1_000 : seconds
                guard abs(normalized) < 253_402_300_800 else { return (nil, text) }
                return (Date(timeIntervalSince1970: normalized), nil)
            }
            return (nil, text)
        }
        return (nil, String(describing: value))
    }
}
