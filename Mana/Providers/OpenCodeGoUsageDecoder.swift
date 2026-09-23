import Foundation
import CoreFoundation

struct OpenCodeGoUsageDecoder {
    static func decode(_ data: Data, now: Date = Date()) throws -> ProviderSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let usage = root["usage"] as? [String: Any] else {
            throw ProviderError.malformedResponse
        }
        let definitions = [("rolling", "5h"), ("weekly", "week"), ("monthly", "month")]
        let windows = definitions.map { key, label -> UsageWindow in
            guard let object = usage[key] as? [String: Any] else {
                return UsageWindow(id: key, label: label, content: .missing, resetAt: nil, resetText: nil)
            }
            let status = object["status"] as? String ?? "unknown"
            let content: WindowContent
            if status != "ok" {
                content = .blocked(status)
            } else if let number = object["percent"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite {
                content = .percent(number.doubleValue)
            } else {
                content = .unknownPercent
            }
            let resetText = object["resetsAt"] as? String
            let resetAt = resetText.flatMap(parseISO8601)
            return UsageWindow(id: key, label: label, content: content,
                               resetAt: resetAt, resetText: resetAt == nil ? resetText : nil)
        }
        return ProviderSnapshot(provider: .openCodeGo, windows: windows, isBlocked: false,
                                blockedReason: nil, receivedAt: now)
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}
