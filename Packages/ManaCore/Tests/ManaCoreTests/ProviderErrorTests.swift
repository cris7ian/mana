import Foundation
import Testing
import ManaCore

@Test func largeRetryIntervalDisplaysWithoutThirtyTwoBitTruncation() {
    let message = ProviderError.rateLimited(retryAfter: 2_147_483_648).localizedDescription
    #expect(message.contains("2147483648"))
}

@Test func retryAfterSupportsSecondsAndHTTPDates() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(RetryAfterParser.interval("120", now: now) == 120)
    #expect(RetryAfterParser.interval("Tue, 14 Nov 2023 22:15:20 GMT", now: now) == 120)
    #expect(RetryAfterParser.interval("Tue, 14 Nov 2023 22:11:20 GMT", now: now) == 0)
    for value in [nil, "", "-1", "inf", "nan", "1e300"] {
        #expect(RetryAfterParser.interval(value, now: now) == nil)
    }
}

@Test(arguments: [Double.infinity, .nan, -1, 1e300])
func invalidRetryIntervalsUseSafeFallbackMessage(value: Double) {
    #expect(ProviderError.rateLimited(retryAfter: value).errorDescription == UsageLocalization.text("Rate limited. Mana will retry at the next refresh."))
}
