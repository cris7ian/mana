import Foundation
import ManaCore

enum MobilePresentation {
    static let staleInterval: TimeInterval = 15 * 60

    static func isStale(receivedAt: Date, now: Date = .now) -> Bool {
        now.timeIntervalSince(receivedAt) > staleInterval
    }

    static func resetText(until date: Date, now: Date = .now) -> String {
        UsageLocalization.countdown(until: date, now: now)
    }
}
