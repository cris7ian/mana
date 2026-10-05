import AppKit
import Darwin
import XCTest
@testable import Mana

final class ManaTests: XCTestCase {
    func testManaIconAssetsLoadWithCorrectRenderingIntent() throws {
        let status = try XCTUnwrap(NSImage(named: "ManaStatusIcon"))
        let brand = try XCTUnwrap(NSImage(named: "ManaBrandIcon"))
        XCTAssertTrue(status.isTemplate)
        XCTAssertFalse(brand.isTemplate)
        XCTAssertEqual(status.size, NSSize(width: 20, height: 22))
        for name in ["Provider-codex", "Provider-opencode", "Provider-antigravity", "Provider-claude"] {
            let icon = try XCTUnwrap(NSImage(named: name))
            XCTAssertFalse(icon.isTemplate)
            XCTAssertGreaterThan(icon.size.width, 0)
        }
    }

    func testAntigravityQuotaUsesFractionsAndOmitsSlidingResets() throws {
        let body = """
        {"status":"SUCCESS","num_turns":0,"command":{"name":"usage","data":{"groups":[
          {"name":"Gemini Models","buckets":[
            {"id":"gemini-weekly","name":"Weekly Limit Remaining","remaining_fraction":0.75,"reset_time":"2026-10-04T14:03:34Z"},
            {"id":"gemini-5h","name":"Five Hour Limit Remaining","remaining_fraction":0.4,"reset_time":"2026-09-27T19:03:34Z"}]},
          {"name":"Claude and GPT models","buckets":[
            {"id":"3p-weekly","name":"Weekly Limit Remaining","remaining_fraction":1,"reset_time":"2026-10-04T14:03:34Z"},
            {"id":"3p-5h","name":"Five Hour Limit Remaining","remaining_fraction":0,"reset_time":"2026-09-27T19:03:34Z"}]}
        ]}}}
        """
        let snapshot = try AntigravityUsageProvider.decode(Data(body.utf8))
        XCTAssertEqual(snapshot.provider, .antigravity)
        XCTAssertEqual(snapshot.windows.map(\.id), ["gemini-weekly", "gemini-5h", "3p-weekly", "3p-5h"])
        XCTAssertEqual(snapshot.windows.map(\.content), [.percent(25), .percent(60), .percent(0), .percent(100)])
        XCTAssertTrue(snapshot.windows.allSatisfy { $0.resetAt == nil && $0.resetText == nil })
        XCTAssertTrue(snapshot.windows[2].label.contains("Antigravity"))
        XCTAssertThrowsError(try AntigravityUsageProvider.decode(Data(body.replacingOccurrences(of: "0.75", with: "1.5").utf8)))
        XCTAssertThrowsError(try AntigravityUsageProvider.decode(Data(body.replacingOccurrences(of: "gemini-weekly", with: "unexpected").utf8)))
        XCTAssertThrowsError(try AntigravityUsageProvider.decode(Data(body.replacingOccurrences(of: "SUCCESS", with: "FAILED").utf8)))
    }

    @MainActor
    func testAntigravityPathSettingAndCLISelection() throws {
        let suiteName = "mana-antigravity-test-\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let settings = UsageSettings(defaults: suite)
        XCTAssertFalse(settings.antigravityEnabled)
        settings.antigravityPath = "/example/agy"
        settings.antigravityEnabled = true
        XCTAssertEqual(UsageSettings.configuredAntigravityPath(defaults: suite), "/example/agy")
        XCTAssertTrue(settings.visibleProviders.contains(.antigravity))
        settings.antigravityEnabled = false
        XCTAssertFalse(settings.visibleProviders.contains(.antigravity))
        XCTAssertEqual(try ManaCLIOptions.parse(["--provider", "antigravity", "--json"]).provider, .antigravity)
    }

    func testOAuthListenerIgnoresInvalidCallbackBeforeValidOne() async throws {
        let listener = try LoopbackOAuthListener(ports: [0])
        defer { listener.close() }
        // Queue all requests before accepting so a slow runner cannot drop the valid callback.
        try sendCallback(to: listener.redirectURI, path: "/other?state=expected&code=bad")
        try sendCallback(to: listener.redirectURI, path: "/auth/callback?state=wrong&code=bad")
        try sendCallback(to: listener.redirectURI, path: "/auth/callback?state=expected&code=good")
        let callback = try listener.waitForCallback(expectedState: "expected", timeout: 2)
        XCTAssertEqual(callback.code, "good")
    }

    func testOAuthListenerTimesOutWhenPeerConnectsWithoutSending() async throws {
        let listener = try LoopbackOAuthListener(ports: [0])
        defer { listener.close() }
        let waiting = Task.detached { try listener.waitForCallback(expectedState: "expected", timeout: 0.2) }
        let client = try connectToListener(listener.redirectURI)
        defer { Darwin.close(client) }
        do {
            _ = try await waiting.value
            XCTFail("Expected callback timeout")
        } catch CodexOAuthError.callbackTimedOut {
            // The idle peer must not keep sign-in blocked.
        }
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
          5h      ███████████████░░░░░  75% left   resets today 23:13
          1w      ████░░░░░░░░░░░░░░░░  20% left   resets Nov 15 22:13
        --------------------------------------------
          requests are currently blocked by a rate limit

        OpenCode Go usage
        --------------------------------------------
          5h      ██████████░░░░░░░░░░  50% left   resets today 23:13
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
        let records = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        let windows = try XCTUnwrap(records[0]["windows"] as? [[String: Any]])
        XCTAssertEqual(windows[0]["usedPercent"] as? Double, 25)
        XCTAssertEqual(windows[0]["remainingPercent"] as? Double, 75)
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
        XCTAssertTrue(colored.contains("\u{001B}[32m██████████░░░░░░░░░░  51%\u{001B}[0m left"))
        XCTAssertTrue(colored.contains("\u{001B}[33m██████████░░░░░░░░░░  50%\u{001B}[0m left"))
        XCTAssertTrue(colored.contains("\u{001B}[31m████░░░░░░░░░░░░░░░░  20%\u{001B}[0m left"))
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
        let settings = makeSettings()
        let good = TestProvider(provider: .openCodeGo, result: .success(sampleSnapshot(.openCodeGo)))
        let bad = TestProvider(provider: .codex, result: .failure(.authentication(statusCode: 401)))
        let coordinator = UsageRefreshCoordinator(providers: [good, bad], settings: settings)
        await coordinator.refreshAll()
        XCTAssertNotNil(coordinator.states[.openCodeGo]?.snapshot)
        XCTAssertEqual(coordinator.states[.codex]?.lastError, .authentication(statusCode: 401))
    }

    @MainActor
    func testRefreshFailureRetainsLastGoodSnapshotAndMarksStale() async {
        let settings = makeSettings()
        let provider = MutableTestProvider(provider: .codex)
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings)
        await coordinator.refresh(.codex)
        let previous = coordinator.states[.codex]
        provider.failNext = true
        await coordinator.refresh(.codex)
        XCTAssertEqual(coordinator.states[.codex]?.snapshot, previous?.snapshot)
        XCTAssertEqual(coordinator.states[.codex]?.lastSuccessAt, previous?.lastSuccessAt)
        XCTAssertEqual(coordinator.states[.codex]?.requestState, .failed(.transport("network unavailable")))
        XCTAssertTrue(coordinator.states[.codex]?.isStale == true)
    }

    @MainActor
    func testSameProviderRequestsDoNotOverlap() async throws {
        let settings = makeSettings()
        let started = expectation(description: "Provider refresh started")
        let provider = GatedTestProvider(provider: .codex, snapshot: sampleSnapshot(.codex), started: started)
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings)
        let first = Task { await coordinator.refresh(.codex, trigger: .manual) }
        await fulfillment(of: [started], timeout: 2)
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
        let settings = makeSettings()
        let started = expectation(description: "Provider refresh started")
        let provider = GatedTestProvider(provider: .codex, snapshot: sampleSnapshot(.codex), started: started)
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings)
        let refresh = Task { await coordinator.refresh(.codex) }
        await fulfillment(of: [started], timeout: 2)

        coordinator.clearSnapshot(for: .codex)
        await provider.release()
        await refresh.value
        XCTAssertNil(coordinator.states[.codex]?.snapshot)
    }

    @MainActor
    func testRetryAfterSkipsAutomaticRefreshButAllowsManualRefresh() async {
        let settings = makeSettings()
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
        let settings = makeSettings()
        let provider = MutableTestProvider(provider: .codex)
        let coordinator = UsageRefreshCoordinator(providers: [provider], settings: settings)
        await coordinator.handleWake()
        XCTAssertEqual(provider.calls, 1)
    }

    @MainActor
    func testSettingsWindowControllerCentersWindowBeforeActivation() async throws {
        let settings = makeSettings()
        let coordinator = UsageRefreshCoordinator(providers: [], settings: settings)
        let store = InMemoryCredentialStore()
        SettingsWindowController.shared.show(
            coordinator: coordinator,
            settings: settings,
            transport: URLSessionTransport(),
            credentialLoader: ProviderCredentialLoader(store: store),
            codexOAuth: CodexOAuthClient(store: store)
        )
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == String(localized: "Mana Settings") })
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        XCTAssertEqual(window.frame.midX, screen.visibleFrame.midX, accuracy: 1)
        XCTAssertEqual(window.frame.midY, screen.visibleFrame.midY, accuracy: 1)
        try await Task.sleep(for: .milliseconds(300))
        window.close()
    }

    @MainActor
    func testSettingsDefaultRefreshIntervalIsSixtySeconds() {
        let settings = makeSettings()
        XCTAssertEqual(settings.refreshInterval, 60)
    }

    @MainActor
    func testConfiguredProvidersAreTheOnlyProvidersVisibleInMenu() {
        let settings = makeSettings(configuredProviders: [.codex, .openCodeGo])

        XCTAssertEqual(settings.visibleProviders, [.codex, .openCodeGo])

        settings.setProviderConfigured(.codex, isConfigured: false)
        XCTAssertEqual(settings.visibleProviders, [.openCodeGo])

        settings.setProviderConfigured(.openCodeGo, isConfigured: false)
        XCTAssertTrue(settings.visibleProviders.isEmpty)

        settings.setProviderConfigured(.codex, isConfigured: true)
        XCTAssertEqual(settings.visibleProviders, [.codex])
    }

    @MainActor
    private func makeSettings(configuredProviders: Set<ProviderID> = []) -> UsageSettings {
        let name = "mana-settings-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return UsageSettings(defaults: defaults, configuredProviders: configuredProviders)
    }

    private func connectToListener(_ url: URL) throws -> Int32 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0, let port = url.port else { throw CodexOAuthError.invalidCallback }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let status = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard status == 0 else {
            Darwin.close(fd)
            throw CodexOAuthError.invalidCallback
        }
        return fd
    }

    private func sendCallback(to url: URL, path: String) throws {
        let fd = try connectToListener(url)
        defer { Darwin.close(fd) }
        let request = "GET \(path) HTTP/1.1\r\nHost: localhost\r\n\r\n"
        _ = request.withCString { send(fd, $0, request.utf8.count, 0) }
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
    private let started: XCTestExpectation
    private var calls = 0
    private var continuation: CheckedContinuation<ProviderSnapshot, Never>?
    init(provider: ProviderID, snapshot: ProviderSnapshot, started: XCTestExpectation) {
        self.provider = provider
        self.snapshot = snapshot
        self.started = started
    }
    func fetchSnapshot() async throws -> ProviderSnapshot {
        calls += 1
        return await withCheckedContinuation {
            continuation = $0
            started.fulfill()
        }
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
