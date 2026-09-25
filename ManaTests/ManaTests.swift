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

    func testCLIParsesProviderAndOutputFlags() throws {
        XCTAssertEqual(try ManaCLIOptions.parse([]), ManaCLIOptions(provider: nil, json: false))
        XCTAssertEqual(try ManaCLIOptions.parse(["--provider", "codex", "--json"]),
                       ManaCLIOptions(provider: .codex, json: true))
        XCTAssertEqual(try ManaCLIOptions.parse(["--provider=opencode-go"]),
                       ManaCLIOptions(provider: .openCodeGo, json: false))
        XCTAssertEqual(try ManaCLIOptions.parse(["--provider", "opencode-go", "--key-stdin"]),
                       ManaCLIOptions(provider: .openCodeGo, json: false, keyFromStdin: true))
        XCTAssertThrowsError(try ManaCLIOptions.parse(["--key-stdin"]))
        XCTAssertThrowsError(try ManaCLIOptions.parse(["--provider", "codex", "--key-stdin"]))
        XCTAssertThrowsError(try ManaCLIOptions.parse(["--provider", "unknown"]))
        XCTAssertThrowsError(try ManaCLIOptions.parse(["--json", "--json"]))
        XCTAssertThrowsError(try ManaCLIOptions.parse(["--provider"]))
        XCTAssertThrowsError(try ManaCLIOptions.parse(["--provider", "all", "--provider", "codex"]))
    }

    func testCLIFormatsReferenceStyleTablesForBothProviders() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let codex = ProviderSnapshot(
            provider: .codex,
            windows: [
                UsageWindow(id: "primary", label: "5h", content: .percent(25), resetAt: now.addingTimeInterval(3_600), resetText: "untrusted reset text"),
                UsageWindow(id: "weekly", label: "1w", content: .percent(80), resetAt: now.addingTimeInterval(86_400), resetText: nil),
                UsageWindow(id: "missing", label: "window 3", content: .missing, resetAt: nil, resetText: nil)
            ],
            isBlocked: true, blockedReason: "rate limit", receivedAt: now
        )
        let openCodeGo = ProviderSnapshot(
            provider: .openCodeGo,
            windows: [
                UsageWindow(id: "rolling", label: "5h", content: .percent(50), resetAt: now.addingTimeInterval(3_600), resetText: nil),
                UsageWindow(id: "weekly", label: "week", content: .blocked("exhausted"), resetAt: nil, resetText: nil),
                UsageWindow(id: "monthly", label: "month", content: .missing, resetAt: nil, resetText: nil)
            ],
            isBlocked: false, blockedReason: nil, receivedAt: now
        )
        let text = ManaCLIOutput.text(
            [.success(codex), .success(openCodeGo)],
            colorEnabled: false,
            now: now,
            timeZone: utc
        )
        let expected = """
        Personal ChatGPT Codex usage
        --------------------------------------------
          5h      █████░░░░░░░░░░░░░░░  25%   resets today 23:13
          1w      ████████████████░░░░  80%   resets Nov 15 22:13
        --------------------------------------------
          requests are currently blocked by a rate limit

        OpenCode Go usage
        --------------------------------------------
          5h      ██████████░░░░░░░░░░  50%   resets today 23:13
          week    status: exhausted
          month   unknown
        --------------------------------------------
        """
        XCTAssertEqual(text, expected + "\n")
        XCTAssertFalse(text.contains("untrusted reset text"))

        let failure = ManaCLIOutput.text(
            [.failure(.openCodeGo, .missingCredential(provider: .openCodeGo, field: "API key"))],
            colorEnabled: false,
            now: now,
            timeZone: utc
        )
        XCTAssertTrue(failure.contains("OpenCode Go usage\n--------------------------------------------\n  error: Add the API key in OpenCode Go settings.\n--------------------------------------------"))

        let json = try ManaCLIOutput.json([
            .success(codex),
            .failure(.openCodeGo, .missingCredential(provider: .openCodeGo, field: "API key"))
        ])
        XCTAssertTrue(json.contains("\"provider\" : \"codex\""))
        XCTAssertTrue(json.contains("\"provider\" : \"openCodeGo\""))
        XCTAssertFalse(json.contains("accessToken"))
    }

    func testCLIColorsUsageBarsOnlyForEligibleTerminals() throws {
        XCTAssertTrue(ManaCLIOutput.shouldUseColor(isTTY: true, environment: ["TERM": "xterm-256color"]))
        XCTAssertFalse(ManaCLIOutput.shouldUseColor(isTTY: false, environment: ["TERM": "xterm-256color"]))
        XCTAssertFalse(ManaCLIOutput.shouldUseColor(isTTY: true, environment: ["TERM": "xterm", "NO_COLOR": "1"]))
        XCTAssertFalse(ManaCLIOutput.shouldUseColor(isTTY: true, environment: ["TERM": "dumb"]))

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let snapshot = ProviderSnapshot(
            provider: .codex,
            windows: [
                UsageWindow(id: "low", label: "5h", content: .percent(49), resetAt: nil, resetText: nil),
                UsageWindow(id: "medium", label: "1d", content: .percent(50), resetAt: nil, resetText: nil),
                UsageWindow(id: "high", label: "1w", content: .percent(80), resetAt: nil, resetText: nil)
            ],
            isBlocked: false, blockedReason: nil, receivedAt: now
        )
        let colored = ManaCLIOutput.text([.success(snapshot)], colorEnabled: true, now: now, timeZone: utc)
        XCTAssertTrue(colored.contains("\u{001B}[32m██████████░░░░░░░░░░  49%\u{001B}[0m"))
        XCTAssertTrue(colored.contains("\u{001B}[33m██████████░░░░░░░░░░  50%\u{001B}[0m"))
        XCTAssertTrue(colored.contains("\u{001B}[31m████████████████░░░░  80%\u{001B}[0m"))
        let plain = ManaCLIOutput.text([.success(snapshot)], colorEnabled: false, now: now, timeZone: utc)
        XCTAssertFalse(plain.contains("\u{001B}"))
    }

    func testFileCredentialStoreUsesPrivatePermissionsAndSupportsReplacement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "mana-credentials-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileCredentialStore(directory: directory)
        let account = ProviderCredentialLoader.openCodeGoAccount
        XCTAssertNil(try store.read(account))
        try store.write(Data("test-one".utf8), account: account)
        try store.write(Data("test-two".utf8), account: account)
        XCTAssertEqual(try store.read(account), Data("test-two".utf8))
        let file = directory.appending(path: "opencode-go-key")
        let directoryMode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int)
        let fileMode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int)
        XCTAssertEqual(directoryMode & 0o777, 0o700)
        XCTAssertEqual(fileMode & 0o777, 0o600)
        XCTAssertThrowsError(try store.write(Data(), account: "../other"))
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        XCTAssertThrowsError(try store.read(account))
        try store.remove(account)
        XCTAssertNil(try store.read(account))
    }

    func testFileCredentialStoreRejectsInsecureDirectory() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "mana-store-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let shared = base.appending(path: "shared")
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shared.path)
        let store = FileCredentialStore(directory: shared)
        XCTAssertThrowsError(try store.write(Data("test".utf8), account: ProviderCredentialLoader.openCodeGoAccount))
        XCTAssertFalse(FileManager.default.fileExists(atPath: shared.appending(path: "opencode-go-key").path))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: shared.path)
        let link = base.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: shared)
        XCTAssertThrowsError(try FileCredentialStore(directory: link)
            .write(Data("test".utf8), account: ProviderCredentialLoader.openCodeGoAccount))
    }

    func testOpenCodeKeyIsSavedAndLoadedWithoutLocalAuthFiles() throws {
        let store = InMemoryCredentialStore()
        let loader = ProviderCredentialLoader(store: store)
        XCTAssertThrowsError(try loader.openCodeGoCredentials())
        XCTAssertFalse(loader.hasOpenCodeGoAPIKey())

        try store.write(Data(" \n ".utf8), account: ProviderCredentialLoader.openCodeGoAccount)
        XCTAssertFalse(loader.hasOpenCodeGoAPIKey())
        XCTAssertThrowsError(try loader.openCodeGoCredentials())

        try loader.saveOpenCodeGoAPIKey("  oc-848-secret  ")
        XCTAssertEqual(try loader.openCodeGoCredentials().apiKey, "oc-848-secret")
        XCTAssertTrue(loader.hasOpenCodeGoAPIKey())

        try loader.removeOpenCodeGoAPIKey()
        XCTAssertFalse(loader.hasOpenCodeGoAPIKey())
        XCTAssertThrowsError(try loader.openCodeGoCredentials())
    }

    @MainActor
    func testCodexOAuthCredentialsLoadFromStoredTokens() async throws {
        let store = InMemoryCredentialStore()
        let tokens = CodexOAuthTokens(
            accessToken: "access",
            refreshToken: "refresh",
            accountID: "account",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        try store.write(JSONEncoder().encode(tokens), account: CodexOAuthClient.credentialAccount)
        let oauth = CodexOAuthClient(store: store, now: { Date(timeIntervalSince1970: 1_900_000_000) })

        XCTAssertTrue(oauth.isSignedIn)
        let credentials = try await oauth.credentials()
        XCTAssertEqual(credentials.accessToken, "access")
        XCTAssertEqual(credentials.accountID, "account")
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
    func testClearingProviderInvalidatesAnInFlightSnapshot() async throws {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let provider = GatedTestProvider(provider: .codex, snapshot: sampleSnapshot(.codex))
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings)
        let refresh = Task { await coordinator.refresh(.codex) }
        for _ in 0..<100 {
            if await provider.callCount() == 1 { break }
            try await Task.sleep(for: .milliseconds(5))
        }

        coordinator.clearSnapshot(for: .codex)
        await provider.release()
        await refresh.value
        XCTAssertNil(coordinator.states[.codex]?.snapshot)
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
    func testSettingsWindowControllerCentersWindowBeforeActivation() async throws {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let coordinator = UsageRefreshCoordinator(providers: [], settings: settings)
        let store = InMemoryCredentialStore()
        SettingsWindowController.shared.show(
            coordinator: coordinator,
            settings: settings,
            transport: URLSessionTransport(),
            credentialLoader: ProviderCredentialLoader(store: store),
            codexOAuth: CodexOAuthClient(store: store)
        )
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == "Mana Settings" })
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        XCTAssertEqual(window.frame.midX, screen.visibleFrame.midX, accuracy: 1)
        XCTAssertEqual(window.frame.midY, screen.visibleFrame.midY, accuracy: 1)
        try await Task.sleep(for: .milliseconds(300))
        window.close()
    }

    @MainActor
    func testSettingsDefaultRefreshIntervalIsSixtySeconds() {
        let settings = UsageSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        XCTAssertEqual(settings.refreshInterval, 60)
    }

    @MainActor
    func testConfiguredProvidersAreTheOnlyProvidersVisibleInMenu() {
        let settings = UsageSettings(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            configuredProviders: [.codex, .openCodeGo]
        )

        XCTAssertEqual(settings.visibleProviders, [.codex, .openCodeGo])

        settings.setProviderConfigured(.codex, isConfigured: false)
        XCTAssertEqual(settings.visibleProviders, [.openCodeGo])

        settings.setProviderConfigured(.openCodeGo, isConfigured: false)
        XCTAssertTrue(settings.visibleProviders.isEmpty)

        settings.setProviderConfigured(.codex, isConfigured: true)
        XCTAssertEqual(settings.visibleProviders, [.codex])
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

private final class InMemoryCredentialStore: ProviderCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func read(_ account: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[account]
    }

    func write(_ data: Data, account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[account] = data
    }

    func remove(_ account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: account)
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
