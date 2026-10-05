import AppIntents
import ManaCore
import XCTest
@testable import ManaIOS

final class ProviderWidgetTimelineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    func testCodexGalleryEntryDefaultsToCodexWithoutDemoLabel() {
        let entry = ProviderTimeline<ProviderWidgetIntent>.preview(for: ProviderWidgetIntent(), now: now)
        XCTAssertEqual(entry.provider, .codex)
        XCTAssertEqual(entry.selection, "rolling")
        XCTAssertFalse(entry.snapshot.isDemo)
        XCTAssertEqual(entry.snapshot.record(entry.provider).snapshot?.displayWindows.count, 2)
    }

    func testGoGalleryEntryDefaultsToGoWithoutDemoLabel() {
        let entry = ProviderTimeline<GoWidgetIntent>.preview(for: GoWidgetIntent(), now: now)
        XCTAssertEqual(entry.provider, .openCodeGo)
        XCTAssertEqual(entry.selection, "rolling")
        XCTAssertFalse(entry.snapshot.isDemo)
        XCTAssertEqual(entry.snapshot.record(entry.provider).snapshot?.displayWindows.count, 3)
    }

    func testGoGalleryPreviewHonorsMonthlyLockScreenSelection() {
        let configuration = GoWidgetIntent()
        configuration.quota = .monthly
        let entry = ProviderTimeline<GoWidgetIntent>.preview(for: configuration, now: now)
        let window = WidgetPolicy.window(entry.snapshot.record(entry.provider), provider: entry.provider, selection: entry.selection)
        XCTAssertEqual(window?.id, "monthly")
        XCTAssertEqual(window?.content.remainingPercent, 33)
    }

    func testExistingProviderIntentStillSupportsGoAndWeeklyQuota() {
        let configuration = ProviderWidgetIntent()
        configuration.provider = .openCodeGo
        configuration.quota = .weekly
        let entry = ProviderTimeline<ProviderWidgetIntent>.preview(for: configuration, now: now)
        XCTAssertEqual(entry.provider, .openCodeGo)
        let window = WidgetPolicy.window(entry.snapshot.record(entry.provider), provider: entry.provider, selection: entry.selection)
        XCTAssertEqual(window?.id, "weekly")
    }

    func testGoTimelinePreservesProviderSelectionAndFreshness() {
        let snapshot = WidgetSnapshot.demo(now: now)
        let entries = widgetEntries(snapshot, provider: .openCodeGo, selection: "monthly")
        XCTAssertTrue(entries.allSatisfy { $0.provider == .openCodeGo && $0.selection == "monthly" && $0.snapshot.isDemo })
        XCTAssertEqual(entries.first?.date, now)
        XCTAssertTrue(entries.contains { $0.snapshot.record(.openCodeGo).isStale(now: $0.date) })
        XCTAssertEqual(WidgetPolicy.nextRefresh(snapshot), now.addingTimeInterval(15 * 60))
    }

    func testTimelineSchedulesFreshnessAndOnlyUpcomingDailyResets() {
        let entries = widgetEntries(.demo(now: now))
        XCTAssertEqual(entries.map(\.date), [now, now.addingTimeInterval(901), now.addingTimeInterval(8_100), now.addingTimeInterval(12_000)])
        XCTAssertTrue(entries.allSatisfy { $0.snapshot.records == entries[0].snapshot.records },
                      "A timeline must not invent quota values when time advances")
    }

    func testMissingSelectedQuotaDoesNotSubstituteAnotherWindow() {
        let snapshot = WidgetSnapshot.preview(now: now)
        XCTAssertNil(WidgetPolicy.window(snapshot.record(.codex), provider: .codex, selection: "monthly"))
    }

    func testProviderBackoffDoesNotPauseTheOtherProvidersRefresh() {
        for (retry, expected) in [(120.0, 120.0), (3_600, 900)] {
            var records = ManaDemo.records(now: now)
            records[.codex]?.retryNotBefore = now.addingTimeInterval(retry)
            let snapshot = WidgetSnapshot(date: now, records: records, isDemo: false)
            XCTAssertEqual(WidgetPolicy.nextRefresh(snapshot), now.addingTimeInterval(expected))
        }
    }
}
