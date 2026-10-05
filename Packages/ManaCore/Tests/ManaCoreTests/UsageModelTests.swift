import Foundation
import Testing
import ManaCore

@Test(arguments: [(0.0, 100.0), (25, 75), (100, 0), (-10, 100), (120, 0)])
func remainingPercentInvertsAndClampsUsage(used: Double, remaining: Double) {
    #expect(WindowContent.percent(used).remainingPercent == remaining)
}

@Test func unavailableAndNonFinitePercentagesNeverBecomeQuotaValues() {
    for content in [WindowContent.unknownPercent, .blocked("blocked"), .missing, .percent(.nan), .percent(.infinity), .percent(-.infinity)] {
        #expect(content.remainingPercent == nil)
    }
}

@Test(arguments: ProviderID.allCases)
func normalizedSnapshotRoundTripPreservesUnknownBlockedAndMissingWindows(provider: ProviderID) throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let snapshot = ProviderSnapshot(provider: provider, windows: [
        UsageWindow(id: "used", label: "5h", content: .percent(25), resetAt: now, resetText: nil),
        UsageWindow(id: "unknown", label: "1w", content: .unknownPercent, resetAt: nil, resetText: "invalid"),
        UsageWindow(id: "blocked", label: "1d", content: .blocked("exhausted"), resetAt: nil, resetText: nil),
        UsageWindow(id: "missing", label: "window 4", content: .missing, resetAt: nil, resetText: nil)
    ], isBlocked: true, blockedReason: "Requests are currently blocked by a rate limit.", receivedAt: now)
    let restored = try JSONDecoder().decode(ProviderSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(restored == snapshot)
    #expect(restored.displayWindows.map(\.id) == ["used", "unknown", "blocked"])
}
