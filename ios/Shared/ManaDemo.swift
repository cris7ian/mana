import Foundation
import ManaCore

enum ManaDemo {
    /// Synthetic values only. This never reads credentials, writes snapshots, or fetches usage.
    static func records(now: Date = .now) -> [ProviderID: MobileProviderRecord] {
        let codex = ProviderSnapshot(provider: .codex, windows: [
            .init(id: "primary_window", label: "5h", content: .percent(28), resetAt: now.addingTimeInterval(8_100), resetText: nil),
            .init(id: "secondary_window", label: "1w", content: .percent(46), resetAt: now.addingTimeInterval(259_200), resetText: nil)
        ], isBlocked: false, blockedReason: nil, receivedAt: now)
        let go = ProviderSnapshot(provider: .openCodeGo, windows: [
            .init(id: "rolling", label: "5h", content: .percent(16), resetAt: now.addingTimeInterval(12_000), resetText: nil),
            .init(id: "weekly", label: "week", content: .percent(38), resetAt: now.addingTimeInterval(345_600), resetText: nil),
            .init(id: "monthly", label: "month", content: .percent(67), resetAt: now.addingTimeInterval(864_000), resetText: nil)
        ], isBlocked: false, blockedReason: nil, receivedAt: now)
        return [.codex: .init(isConfigured: true, snapshot: codex), .openCodeGo: .init(isConfigured: true, snapshot: go)]
    }
}
