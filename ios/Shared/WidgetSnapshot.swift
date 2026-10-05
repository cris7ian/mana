import Foundation
import ManaCore

struct WidgetSnapshot: Sendable {
    let date: Date
    let records: [ProviderID: MobileProviderRecord]
    let isDemo: Bool

    static func preview(now: Date = .now) -> WidgetSnapshot {
        // Gallery samples are not the app's Demo mode. Never load accounts here.
        .init(date: now, records: ManaDemo.records(now: now), isDemo: false)
    }

    static func demo(now: Date = .now) -> WidgetSnapshot {
        .init(date: now, records: ManaDemo.records(now: now), isDemo: true)
    }

    func record(_ provider: ProviderID) -> MobileProviderRecord {
        records[provider] ?? MobileProviderRecord()
    }
}

enum WidgetRefresh {
    static func load(demo: Bool, now: Date = .now,
                     runtimeFactory: @Sendable () throws -> MobileUsageRuntime = MobileUsageRuntime.live,
                     isDemoEnabled: @escaping @Sendable () -> Bool = { demoEnabled },
                     executionBudget: Duration = .seconds(20)) async -> WidgetSnapshot {
        if demo || isDemoEnabled() { return .demo(now: now) }
        do {
            let runtime = try runtimeFactory()
            let result = await withTaskGroup(of: LoadResult.self, returning: LoadResult.self) { group in
                group.addTask { .records(await runtime.refreshAll(allowLiveAccess: { !isDemoEnabled() })) }
                group.addTask {
                    let clock = ContinuousClock()
                    let deadline = clock.now.advanced(by: executionBudget)
                    do {
                        while clock.now < deadline {
                            if isDemoEnabled() { return .demo }
                            try await Task.sleep(for: min(.milliseconds(100), clock.now.duration(to: deadline)))
                        }
                    } catch { return .expired }
                    return .expired
                }
                let first = await group.next() ?? .expired
                group.cancelAll()
                return first
            }
            if isDemoEnabled() { return .demo() }
            switch result {
            case .demo: return .demo()
            case .records(let records): return .init(date: .now, records: records, isDemo: false)
            case .expired:
                let cached = Dictionary(uniqueKeysWithValues: MobileStore.providers.map { provider in
                    (provider, (try? runtime.store.read(provider, recoverCredentialState: false)) ?? MobileProviderRecord())
                })
                return .init(date: .now, records: cached, isDemo: false)
            }
        } catch {
            return .init(date: now, records: [:], isDemo: false)
        }
    }

    static var demoEnabled: Bool { UserDefaults(suiteName: MobileStore.groupID)?.bool(forKey: "demoMode") == true }
    private enum LoadResult: Sendable {
        case records([ProviderID: MobileProviderRecord]), demo, expired
    }
}

enum WidgetPolicy {
    static func timelineDates(_ snapshot: WidgetSnapshot) -> [Date] {
        var dates: Set<Date> = [snapshot.date]
        for record in snapshot.records.values {
            guard let usage = record.snapshot else { continue }
            let staleAt = usage.receivedAt.addingTimeInterval(MobilePresentation.staleInterval + 1)
            if staleAt > snapshot.date { dates.insert(staleAt) }
            for window in usage.displayWindows {
                if let reset = window.resetAt, reset > snapshot.date, reset < snapshot.date.addingTimeInterval(86_400) {
                    dates.insert(reset)
                }
            }
        }
        return dates.sorted()
    }

    static func nextRefresh(_ snapshot: WidgetSnapshot) -> Date {
        // iOS grants timeline execution. This is a request, never a guaranteed polling interval.
        let normal = snapshot.date.addingTimeInterval(15 * 60)
        let backoff = snapshot.records.values.compactMap(\.retryNotBefore).filter { $0 > snapshot.date }.min()
        // Keep the other provider refreshing independently; runtime honors each provider's own backoff.
        return min(normal, backoff ?? normal)
    }

    static func window(_ record: MobileProviderRecord, provider: ProviderID, selection: String) -> UsageWindow? {
        if provider == .codex && selection == "monthly" { return nil }
        let id: String
        switch (provider, selection) {
        case (.codex, "weekly"): id = "secondary_window"
        case (.codex, _): id = "primary_window"
        case (_, "weekly"): id = "weekly"
        case (_, "monthly"): id = "monthly"
        default: id = "rolling"
        }
        return record.snapshot?.displayWindows.first { $0.id == id }
    }
}
