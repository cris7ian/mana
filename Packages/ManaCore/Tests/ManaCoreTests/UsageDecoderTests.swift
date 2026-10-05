import Foundation
import Testing
import ManaCore

@Test func codexFixturePreservesWindowLabelsPercentagesAndResets() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let snapshot = try CodexUsageDecoder.decode(fixture("codex_valid"), now: now)
    #expect(snapshot.provider == .codex)
    #expect(snapshot.receivedAt == now)
    #expect(!snapshot.isBlocked)
    #expect(snapshot.windows.map(\.label) == ["5h", "1w"])
    #expect(snapshot.windows.map(\.content) == [.percent(42.5), .percent(71)])
    #expect(snapshot.windows.map(\.resetAt) == [Date(timeIntervalSince1970: 1_790_200_000), Date(timeIntervalSince1970: 1_790_300_000)])
}

@Test func goFixturePreservesAllWindowsAndBothISODateFormats() throws {
    let snapshot = try OpenCodeGoUsageDecoder.decode(fixture("go_valid"))
    #expect(snapshot.provider == .openCodeGo)
    #expect(snapshot.windows.map(\.label) == ["5h", "week", "month"])
    #expect(snapshot.windows.map(\.content) == [.percent(25), .percent(63.5), .percent(91)])
    #expect(snapshot.windows.allSatisfy { $0.resetAt != nil && $0.resetText == nil })
}

@Test(arguments: [ProviderID.codex, .openCodeGo])
func missingUnknownAndBlockedWindowsRemainExplicit(provider: ProviderID) throws {
    if provider == .codex {
        let snapshot = try CodexUsageDecoder.decode(fixture("codex_blocked_missing"))
        #expect(snapshot.isBlocked)
        #expect(snapshot.windows[0].content == .unknownPercent)
        #expect(snapshot.windows[0].resetText == "invalid")
        #expect(snapshot.windows[1].content == .missing)
        #expect(snapshot.displayWindows.map(\.id) == ["primary_window"])
    } else {
        let snapshot = try OpenCodeGoUsageDecoder.decode(fixture("go_status_missing"))
        #expect(snapshot.windows.map(\.content) == [.blocked("exhausted"), .unknownPercent, .missing])
        #expect(snapshot.displayWindows.map(\.id) == ["rolling", "weekly"])
    }
}

@Test(arguments: [ProviderID.codex, .openCodeGo], ["null", "[]", "{}", "not JSON", "{\"unexpected\":true}", "{\"rate_limit\":[],\"usage\":false}"])
func decodersRejectMalformedEnvelopes(provider: ProviderID, json: String) {
    #expect(throws: ProviderError.malformedResponse) {
        _ = try decode(provider, data: Data(json.utf8))
    }
}

@Test(arguments: [ProviderID.codex, .openCodeGo], ["true", "null", "\"42\"", "1e300"])
func percentagesKeepInvalidValuesUnknownAndClampLargeNumbers(provider: ProviderID, value: String) throws {
    let object = provider == .codex
        ? "{\"rate_limit\":{\"primary_window\":{\"used_percent\":\(value)}}}"
        : "{\"usage\":{\"rolling\":{\"status\":\"ok\",\"percent\":\(value)}}}"
    let snapshot = try decode(provider, data: Data(object.utf8))
    if value == "1e300" {
        #expect(snapshot.windows[0].content.remainingPercent == 0)
    } else {
        #expect(snapshot.windows[0].content == .unknownPercent)
    }
}

@Test func codexGiantWindowDurationUsesFallbackLabelWithoutTrapping() throws {
    let data = Data(#"{"rate_limit":{"primary_window":{"limit_window_seconds":1e300,"used_percent":25}}}"#.utf8)
    let snapshot = try CodexUsageDecoder.decode(data)
    #expect(snapshot.windows[0].label == "window 1")
    #expect(snapshot.windows[0].content == .percent(25))
}

private func decode(_ provider: ProviderID, data: Data) throws -> ProviderSnapshot {
    provider == .codex ? try CodexUsageDecoder.decode(data) : try OpenCodeGoUsageDecoder.decode(data)
}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}
