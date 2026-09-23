import AppKit
import XCTest
@testable import Mana

final class ManaTests: XCTestCase {
    func testCodexFixtureDecodesWindowsLabelsAndPercentages() throws {
        let snapshot = try CodexUsageDecoder.decode(fixture("codex_valid"))
        XCTAssertEqual(snapshot.provider, .codex)
        XCTAssertFalse(snapshot.isBlocked)
        XCTAssertEqual(snapshot.windows.map(\.label), ["5h", "1w"])
        XCTAssertEqual(snapshot.windows[0].content, .percent(42.5))
        XCTAssertNotNil(snapshot.windows[0].resetAt)
    }

    func testCodexBlockedAndMissingValuesRemainExplicit() throws {
        let snapshot = try CodexUsageDecoder.decode(fixture("codex_blocked_missing"))
        XCTAssertTrue(snapshot.isBlocked)
        XCTAssertEqual(snapshot.windows[0].content, .unknownPercent)
        XCTAssertEqual(snapshot.windows[0].resetText, "invalid")
        XCTAssertEqual(snapshot.windows[1].content, .missing)
        XCTAssertEqual(snapshot.displayWindows.map(\.id), ["primary_window"])
    }

    func testGoFixtureDecodesAllWindowsAndStatuses() throws {
        let snapshot = try OpenCodeGoUsageDecoder.decode(fixture("go_valid"))
        XCTAssertEqual(snapshot.windows.map(\.label), ["5h", "week", "month"])
        XCTAssertEqual(snapshot.windows[0].content, .percent(25))
        XCTAssertNotNil(snapshot.windows[1].resetAt)
        let partial = try OpenCodeGoUsageDecoder.decode(fixture("go_status_missing"))
        XCTAssertEqual(partial.windows[0].content, .blocked("exhausted"))
        XCTAssertEqual(partial.windows[1].content, .unknownPercent)
        XCTAssertEqual(partial.windows[2].content, .missing)
    }

    func testUnexpectedEnvelopesAreRejected() throws {
        XCTAssertThrowsError(try CodexUsageDecoder.decode(fixture("unexpected")))
        XCTAssertThrowsError(try OpenCodeGoUsageDecoder.decode(fixture("unexpected")))
    }

    func testClientRequestsUseExpectedURLsHeadersAndTimeouts() throws {
        let codex = try CodexUsageClient().makeRequest(credentials: .init(accessToken: "token", accountID: "acct"))
        XCTAssertEqual(codex.url, CodexUsageClient.usageURL)
        XCTAssertEqual(codex.timeoutInterval, 15)
        XCTAssertEqual(codex.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(codex.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "acct")
        XCTAssertEqual(codex.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(codex.value(forHTTPHeaderField: "User-Agent"), "codexusage/1.0")

        let go = try OpenCodeGoUsageClient().makeRequest(credentials: .init(apiKey: "key"))
        XCTAssertEqual(go.url, OpenCodeGoUsageClient.usageURL)
        XCTAssertEqual(go.timeoutInterval, 15)
        XCTAssertEqual(go.value(forHTTPHeaderField: "Authorization"), "Bearer key")
        XCTAssertEqual(go.value(forHTTPHeaderField: "User-Agent"), "gousage/1.0")
    }

    func testClientsRejectMissingCredentialsAndClassifyStatuses() throws {
        XCTAssertThrowsError(try CodexUsageClient().makeRequest(credentials: .init(accessToken: "", accountID: "acct")))
        XCTAssertThrowsError(try OpenCodeGoUsageClient().makeRequest(credentials: .init(apiKey: " ")))
        XCTAssertThrowsError(try CodexUsageClient.validate(statusCode: 401, retryAfter: nil)) { error in
            XCTAssertEqual(error as? ProviderError, .authentication(statusCode: 401))
        }
        XCTAssertThrowsError(try OpenCodeGoUsageClient.validate(statusCode: 429, retryAfter: 42)) { error in
            XCTAssertEqual(error as? ProviderError, .rateLimited(retryAfter: 42))
        }
        XCTAssertThrowsError(try CodexUsageClient.validate(statusCode: 500, retryAfter: nil)) { error in
            XCTAssertEqual(error as? ProviderError, .response(statusCode: 500))
        }
    }

    func testTypedErrorsDoNotContainResponseBodies() {
        let error = ProviderError.response(statusCode: 500)
        XCTAssertFalse(error.localizedDescription.contains("secret"))
        XCTAssertEqual(RetryAfterParser.interval("120"), 120)
    }

    func testCredentialLoaderReadsPiAndExcludesCodexCLIAuth() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        try writeAuth(#"{"openai-codex":{"access":"pi-token","accountId":"pi-account"}}"#, to: ".pi/agent/auth.json", home: home)
        try writeAuth(#"{"openai-codex":{"access":"work-token","accountId":"work-account"}}"#, to: ".codex/auth.json", home: home)
        let credentials = try ProviderCredentialLoader(homeDirectory: home).codexCredentials()
        XCTAssertEqual(credentials.accessToken, "pi-token")
        XCTAssertEqual(credentials.accountID, "pi-account")

        let otherHome = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: otherHome) }
        try writeAuth(#"{"openai-codex":{"access":"work-token","accountId":"work-account"}}"#, to: ".codex/auth.json", home: otherHome)
        XCTAssertThrowsError(try ProviderCredentialLoader(homeDirectory: otherHome).codexCredentials())
    }

    func testCredentialLoaderReadsOpenCodeGoKey() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        try writeAuth(#"{"opencode-go":{"key":"go-key"},"opencode":{"key":"fallback"}}"#, to: ".local/share/opencode/auth.json", home: home)
        let credentials = try ProviderCredentialLoader(homeDirectory: home).openCodeGoCredentials()
        XCTAssertEqual(credentials.apiKey, "go-key")
    }

    @MainActor
    func testRefreshCoordinatorKeepsGoodProviderWhenOtherFails() async {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let good = TestProvider(provider: .openCodeGo, result: .success(sampleSnapshot(.openCodeGo)))
        let bad = TestProvider(provider: .codex, result: .failure(.authentication(statusCode: 401)))
        let coordinator = UsageRefreshCoordinator(providers: [good, bad], settings: settings)
        await coordinator.refreshAll()
        XCTAssertNotNil(coordinator.states[.openCodeGo]?.snapshot)
        XCTAssertEqual(coordinator.states[.codex]?.lastError, .authentication(statusCode: 401))
    }

    @MainActor
    func testRefreshFailureRetainsLastGoodSnapshotAndMarksStale() async {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let provider = MutableTestProvider(provider: .codex)
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings)
        await coordinator.refresh(.codex)
        provider.failNext = true
        await coordinator.refresh(.codex)
        XCTAssertNotNil(coordinator.states[.codex]?.snapshot)
        XCTAssertTrue(coordinator.states[.codex]?.isStale == true)
    }

    @MainActor
    func testSameProviderRequestsDoNotOverlap() async throws {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let provider = GatedTestProvider(provider: .codex, snapshot: sampleSnapshot(.codex))
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings)
        let first = Task { await coordinator.refresh(.codex, trigger: .manual) }
        for _ in 0..<100 {
            if await provider.callCount() == 1 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let countAfterFirstStart = await provider.callCount()
        XCTAssertEqual(countAfterFirstStart, 1)
        await coordinator.refresh(.codex, trigger: .manual)
        let countAfterOverlap = await provider.callCount()
        XCTAssertEqual(countAfterOverlap, 1)
        await provider.release()
        await first.value
        XCTAssertNotNil(coordinator.states[.codex]?.snapshot)
    }

    @MainActor
    func testRetryAfterSkipsAutomaticRefreshButAllowsManualRefresh() async {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let provider = MutableTestProvider(provider: .codex)
        provider.rateLimitNext = true
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings, now: { now })
        await coordinator.refresh(.codex, trigger: .manual)
        XCTAssertEqual(provider.calls, 1)
        XCTAssertEqual(coordinator.states[.codex]?.retryNotBefore, now.addingTimeInterval(120))
        await coordinator.refresh(.codex, trigger: .automatic)
        XCTAssertEqual(provider.calls, 1)
        await coordinator.refresh(.codex, trigger: .manual)
        XCTAssertEqual(provider.calls, 2)
        XCTAssertNotNil(coordinator.states[.codex]?.snapshot)
    }

    @MainActor
    func testWakeRefreshesProviders() async {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let provider = MutableTestProvider(provider: .codex)
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings)
        await coordinator.handleWake()
        XCTAssertEqual(provider.calls, 1)
    }

    @MainActor
    func testSettingsWindowControllerPresentsVisibleWindow() {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let coordinator = UsageRefreshCoordinator(providers: [], settings: settings)
        SettingsWindowController.shared.show(coordinator: coordinator, settings: settings, transport: URLSessionTransport())
        let window = NSApp.windows.first { $0.title == "Mana Settings" }
        XCTAssertTrue(window?.isVisible == true)
        window?.close()
    }

    @MainActor
    func testSettingsDefaultRefreshIntervalIsSixtySeconds() {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        XCTAssertEqual(settings.refreshInterval, 60)
    }

    private func writeAuth(_ contents: String, to path: String, home: URL) throws {
        let url = home.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else { throw NSError(domain: "ManaTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture not found: \(name)"]) }
        return try Data(contentsOf: url)
    }

    private func sampleSnapshot(_ provider: ProviderID) -> ProviderSnapshot {
        ProviderSnapshot(provider: provider,
                         windows: [UsageWindow(id: "rolling", label: "5h", content: .percent(25), resetAt: nil, resetText: nil)],
                         isBlocked: false, blockedReason: nil, receivedAt: Date())
    }
}

private struct TestProvider: UsageProviding {
    let provider: ProviderID
    let result: Result<ProviderSnapshot, ProviderError>
    func fetchSnapshot() async throws -> ProviderSnapshot { try result.get() }
}

private actor GatedTestProvider: UsageProviding {
    nonisolated let provider: ProviderID
    private let snapshot: ProviderSnapshot
    private var calls = 0
    private var continuation: CheckedContinuation<ProviderSnapshot, Never>?
    init(provider: ProviderID, snapshot: ProviderSnapshot) { self.provider = provider; self.snapshot = snapshot }
    func fetchSnapshot() async throws -> ProviderSnapshot {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func callCount() -> Int { calls }
    func release() { continuation?.resume(returning: snapshot); continuation = nil }
}

@MainActor
private final class MutableTestProvider: UsageProviding {
    let provider: ProviderID
    var failNext = false
    var rateLimitNext = false
    var calls = 0
    init(provider: ProviderID) { self.provider = provider }
    func fetchSnapshot() async throws -> ProviderSnapshot {
        calls += 1
        if rateLimitNext { rateLimitNext = false; throw ProviderError.rateLimited(retryAfter: 120) }
        if failNext { failNext = false; throw ProviderError.transport("network unavailable") }
        return ProviderSnapshot(provider: provider,
                                windows: [UsageWindow(id: "primary_window", label: "5h", content: .percent(10), resetAt: nil, resetText: nil)],
                                isBlocked: false, blockedReason: nil, receivedAt: Date())
    }
}
