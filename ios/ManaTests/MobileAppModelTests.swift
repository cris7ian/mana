import XCTest
import ManaCore
@testable import ManaIOS

@MainActor
final class MobileAppModelTests: XCTestCase {
    func testDemoIsOffByDefault() {
        var saved: [Bool] = []
        let runtime = TestRuntime(records: [:]) { _ in .init() }
        let model = MobileAppModel(runtimeFactory: { runtime }, saveDemo: { saved.append($0) }, reloadWidgets: {})
        XCTAssertFalse(model.isDemo)
        XCTAssertFalse(model.hasConnections)
        XCTAssertEqual(saved, [false])
    }

    func testDemoNeverConstructsLiveRuntime() async {
        var calls = 0
        let model = MobileAppModel(demo: true, runtimeFactory: {
            calls += 1
            throw TestError.unavailable
        }, saveDemo: { _ in }, reloadWidgets: {})

        await model.refresh()
        await model.connectGo("sample-key-not-a-credential")
        await model.beginCodex()
        await model.disconnect(.codex)
        model.setActive(true)
        model.setActive(false)

        XCTAssertEqual(calls, 0)
        XCTAssertTrue(model.isDemo)
        XCTAssertEqual(model.records[.codex]?.snapshot?.displayWindows.count, 2)
        XCTAssertEqual(model.records[.openCodeGo]?.snapshot?.displayWindows.count, 3)
    }

    func testTurningDemoOffClearsSamplesAndHandlesUnavailableRuntime() async {
        var calls = 0
        var saved: [Bool] = []
        let model = MobileAppModel(demo: true, runtimeFactory: {
            calls += 1
            throw TestError.unavailable
        }, saveDemo: { saved.append($0) }, reloadWidgets: {})

        await model.setDemo(false)

        XCTAssertFalse(model.isDemo)
        XCTAssertTrue(model.records.values.allSatisfy { $0.snapshot == nil })
        XCTAssertFalse(model.hasConnections)
        XCTAssertNotNil(model.serviceError)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(saved, [true, false])
    }

    func testOneProviderFailureDoesNotHideOtherProviderUsage() async {
        let samples = ManaDemo.records()
        let runtime = TestRuntime(records: samples) { provider in
            if provider == .codex { throw TestError.unavailable }
            return samples[provider]!
        }
        let model = MobileAppModel(demo: false, runtimeFactory: { runtime }, saveDemo: { _ in }, reloadWidgets: {})

        await model.refresh(force: true)

        XCTAssertNotNil(model.records[.codex]?.lastError)
        XCTAssertNotNil(model.records[.codex]?.snapshot, "Keep the last known usage after an error")
        XCTAssertNil(model.records[.openCodeGo]?.lastError)
        XCTAssertEqual(model.records[.openCodeGo]?.snapshot, samples[.openCodeGo]?.snapshot)
        XCTAssertTrue(model.loading.isEmpty)
    }

    func testEnablingDemoAwaitsAndDiscardsPendingLiveRefresh() async {
        let gate = RefreshGate()
        let sample = ManaDemo.records()[.codex]!
        let runtime = TestRuntime(records: [.codex: sample]) { _ in await gate.fetch() }
        let model = MobileAppModel(demo: false, runtimeFactory: { runtime }, saveDemo: { _ in }, reloadWidgets: {})
        let refresh = Task { await model.refresh(force: true) }
        await gate.waitUntilStarted()

        let switching = Task { await model.setDemo(true) }
        while !model.isDemo { await Task.yield() }
        XCTAssertTrue(model.isSwitching, "Demo must wait for cancelled live work to finish")
        let oldResult = MobileProviderRecord(isConfigured: true, snapshot: .init(provider: .codex, windows: [
            .init(id: "late", label: "5h", content: .percent(99), resetAt: nil, resetText: nil)
        ], isBlocked: false, blockedReason: nil, receivedAt: .now))
        await gate.finish(oldResult)
        await switching.value
        await refresh.value

        XCTAssertTrue(model.isDemo)
        XCTAssertFalse(model.isSwitching)
        XCTAssertEqual(model.records[.codex]?.snapshot?.windows.first?.content.remainingPercent, 72)
        XCTAssertTrue(model.loading.isEmpty)
        let cancelled = await gate.wasCancelled
        XCTAssertTrue(cancelled)
    }

    func testInactiveSceneCancelsRefreshAndForegroundRestartsIt() async {
        let counter = CancellationCounter()
        let sample = ManaDemo.records()[.codex]!
        let runtime = TestRuntime(records: [.codex: sample]) { _ in try await counter.fetch() }
        let model = MobileAppModel(demo: false, runtimeFactory: { runtime }, saveDemo: { _ in }, reloadWidgets: {},
                                   refreshInterval: .seconds(60))

        model.setActive(true)
        await counter.waitForStarts(1)
        XCTAssertTrue(model.loading.contains(.codex))
        model.setActive(false)
        await counter.waitForCancellations(1)
        while !model.loading.isEmpty { await Task.yield() }
        XCTAssertFalse(model.isActive)
        XCTAssertNil(model.records[.codex]?.lastError, "Lifecycle cancellation is not a provider error")

        model.setActive(true)
        await counter.waitForStarts(2)
        model.setActive(false)
        await counter.waitForCancellations(2)
        while !model.loading.isEmpty { await Task.yield() }
        let starts = await counter.starts
        XCTAssertEqual(starts, 2)
    }

    func testCancellingRefreshCallerDiscardsLateResults() async {
        let gate = RefreshGate()
        let sample = ManaDemo.records()[.codex]!
        let runtime = TestRuntime(records: [.codex: sample]) { _ in await gate.fetch() }
        let model = MobileAppModel(demo: false, runtimeFactory: { runtime }, saveDemo: { _ in }, reloadWidgets: {})
        let refresh = Task { await model.refresh(force: true) }
        await gate.waitUntilStarted()

        refresh.cancel()
        await gate.finish(.init(isConfigured: true, lastError: "Late result must not appear"))
        await refresh.value

        XCTAssertEqual(model.records[.codex], sample)
        XCTAssertTrue(model.loading.isEmpty)
        let cancelled = await gate.wasCancelled
        XCTAssertTrue(cancelled)
    }

    func testCancellingCodexAfterApprovalKeepsSavedConnectionVisible() async throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        let transport = ApprovedCodexTransport()
        let runtime = MobileUsageRuntime(store: store, transport: transport)
        let model = MobileAppModel(demo: false, runtimeFactory: { runtime }, saveDemo: { _ in }, reloadWidgets: {})
        let signIn = Task { await model.beginCodex() }
        await transport.waitForUsage()
        XCTAssertTrue(try store.read(.codex).isConfigured)
        await model.cancelAuthentication()
        await signIn.value

        XCTAssertTrue(model.records[.codex]?.isConfigured == true,
                      "Committed approval must remain visible after cancelling the initial quota request")
        XCTAssertTrue(model.hasConnections)
        XCTAssertNil(model.authProvider)
        XCTAssertNotNil(try credentials.read(store.account(.codex)))
        XCTAssertEqual(model.records[.codex], try store.read(.codex))
    }

    func testDemoActivationDrainsQueuedDisconnectWithoutMutatingLiveAccount() async throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        let original = try XCTUnwrap(ManaDemo.records()[.openCodeGo])
        try store.write(original, provider: .openCodeGo)
        let syntheticKey = Data(UUID().uuidString.utf8)
        try credentials.write(syntheticKey, account: store.account(.openCodeGo))
        let gate = DisconnectGate()
        let blocker = Task { try await store.withLock(.openCodeGo) { await gate.holdLock() } }
        await gate.waitForLock()
        let runtime = QueuedDisconnectRuntime(live: MobileUsageRuntime(store: store), gate: gate)
        let model = MobileAppModel(demo: false, runtimeFactory: { runtime }, saveDemo: { _ in }, reloadWidgets: {})
        let disconnect = Task { await model.disconnect(.openCodeGo) }
        await gate.waitForDisconnect()

        await model.setDemo(true)
        XCTAssertFalse(model.isSwitching)
        let drained = await gate.disconnectFinished
        XCTAssertTrue(drained, "Demo must drain live disconnects before completing activation")
        await gate.releaseLock()
        try await blocker.value
        await disconnect.value
        XCTAssertEqual(try store.read(.openCodeGo), original)
        XCTAssertTrue(try credentials.read(store.account(.openCodeGo)) == syntheticKey)
        XCTAssertTrue(model.isDemo)
        XCTAssertNil(model.serviceError)
    }

    func testCodexBrowserRoundTripKeepsIntentAfterInterruptedPoll() async throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        let retryStarted = expectation(description: "The existing approval is polled again")
        let transport = BrowserRoundTripTransport(retryStarted: retryStarted)
        let runtime = MobileUsageRuntime(store: store, transport: transport, authSleep: { _ in })
        let model = MobileAppModel(demo: false, runtimeFactory: { runtime }, saveDemo: { _ in }, reloadWidgets: {})
        model.setActive(true)
        let connection = Task { await model.beginCodex() }
        await transport.waitForInitialPoll()
        let originalIntent = try XCTUnwrap(model.signIn)

        model.setActive(false)
        await transport.interruptPoll()
        await fulfillment(of: [retryStarted], timeout: 2)
        XCTAssertEqual(model.signIn?.authorization.deviceAuthID, originalIntent.authorization.deviceAuthID,
                       "A background request interruption must not reset the approval screen")
        XCTAssertEqual(model.authProvider, .codex)
        XCTAssertNil(model.authError)
        model.setActive(true)
        await transport.approve()
        await connection.value
        model.setActive(false)

        let codeRequests = await transport.codeRequests
        XCTAssertEqual(codeRequests, 1, "Returning from the browser must not request a different code")
        XCTAssertTrue(model.records[.codex]?.isConfigured == true)
        XCTAssertTrue(try store.read(.codex).isConfigured)
        XCTAssertNil(model.signIn)
    }
}

private enum TestError: Error { case unavailable }

private struct TestRuntime: MobileAppRuntime {
    let records: [ProviderID: MobileProviderRecord]
    var fetch: @Sendable (ProviderID) async throws -> MobileProviderRecord

    func read(_ provider: ProviderID) throws -> MobileProviderRecord { records[provider] ?? .init() }
    func refresh(_ provider: ProviderID, force: Bool) async throws -> MobileProviderRecord { try await fetch(provider) }
    func connectGo(_ key: String) async throws -> MobileProviderRecord { throw TestError.unavailable }
    func beginCodex() async throws -> CodexSignIn { throw TestError.unavailable }
    func completeCodex(_ signIn: CodexSignIn) async throws -> MobileProviderRecord { throw TestError.unavailable }
    func disconnect(_ provider: ProviderID) async throws {}
}

private actor RefreshGate {
    private var result: CheckedContinuation<MobileProviderRecord, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var wasCancelled = false

    func fetch() async -> MobileProviderRecord {
        let record = await withCheckedContinuation { continuation in
            result = continuation
            started?.resume()
            started = nil
        }
        wasCancelled = Task.isCancelled
        return record
    }
    func waitUntilStarted() async {
        if result != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(_ record: MobileProviderRecord) { result?.resume(returning: record); result = nil }
}

private actor CancellationCounter {
    private(set) var starts = 0
    private var cancellations = 0
    private var startWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var cancelWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func fetch() async throws -> MobileProviderRecord {
        starts += 1
        startWaiters.removeAll { target, continuation in
            if starts >= target { continuation.resume(); return true }
            return false
        }
        do {
            try await Task.sleep(for: .seconds(120))
            return .init()
        } catch {
            cancellations += 1
            cancelWaiters.removeAll { target, continuation in
                if cancellations >= target { continuation.resume(); return true }
                return false
            }
            throw error
        }
    }
    func waitForStarts(_ target: Int) async {
        if starts >= target { return }
        await withCheckedContinuation { startWaiters.append((target, $0)) }
    }
    func waitForCancellations(_ target: Int) async {
        if cancellations >= target { return }
        await withCheckedContinuation { cancelWaiters.append((target, $0)) }
    }
}

private actor ApprovedCodexTransport: HTTPTransport {
    private var usageStarted = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let object: [String: Any]
        switch request.url?.path {
        case "/api/accounts/deviceauth/usercode":
            object = ["device_auth_id": UUID().uuidString, "user_code": "TEST-CODE", "interval": "5"]
        case "/api/accounts/deviceauth/token":
            object = ["authorization_code": "synthetic-code", "code_verifier": String(repeating: "v", count: 43),
                      "code_challenge": String(repeating: "c", count: 43)]
        case "/oauth/token":
            let claims = try JSONSerialization.data(withJSONObject: ["https://api.openai.com/auth": ["chatgpt_account_id": "synthetic-account"]])
            let payload = claims.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
            object = ["access_token": UUID().uuidString, "refresh_token": UUID().uuidString,
                      "id_token": "e30.\(payload).synthetic-signature", "expires_in": 3600]
        case "/backend-api/wham/usage":
            usageStarted = true
            waiters.forEach { $0.resume() }
            waiters = []
            try await Task.sleep(for: .seconds(60))
            throw URLError(.cancelled)
        default: throw URLError(.badURL)
        }
        return HTTPResponse(data: try JSONSerialization.data(withJSONObject: object), statusCode: 200, retryAfter: nil)
    }

    func waitForUsage() async {
        if usageStarted { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private struct QueuedDisconnectRuntime: MobileAppRuntime {
    let live: MobileUsageRuntime
    let gate: DisconnectGate
    func read(_ provider: ProviderID) throws -> MobileProviderRecord { try live.read(provider) }
    func refresh(_ provider: ProviderID, force: Bool) async throws -> MobileProviderRecord { try await live.refresh(provider, force: force) }
    func connectGo(_ key: String) async throws -> MobileProviderRecord { try await live.connectGo(key) }
    func beginCodex() async throws -> CodexSignIn { try await live.beginCodex() }
    func completeCodex(_ signIn: CodexSignIn) async throws -> MobileProviderRecord { try await live.completeCodex(signIn) }
    func disconnect(_ provider: ProviderID) async throws {
        await gate.markDisconnectStarted()
        do {
            try await live.disconnect(provider)
            await gate.markDisconnectFinished()
        } catch {
            await gate.markDisconnectFinished()
            throw error
        }
    }
}

private actor DisconnectGate {
    private var lockHeld = false
    private var disconnectStarted = false
    private(set) var disconnectFinished = false
    private var lockWaiter: CheckedContinuation<Void, Never>?
    private var disconnectWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func holdLock() async {
        lockHeld = true
        lockWaiter?.resume(); lockWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }
    func waitForLock() async {
        if lockHeld { return }
        await withCheckedContinuation { lockWaiter = $0 }
    }
    func markDisconnectStarted() {
        disconnectStarted = true
        disconnectWaiter?.resume(); disconnectWaiter = nil
    }
    func waitForDisconnect() async {
        if disconnectStarted { return }
        await withCheckedContinuation { disconnectWaiter = $0 }
    }
    func markDisconnectFinished() { disconnectFinished = true }
    func releaseLock() { releaseWaiter?.resume(); releaseWaiter = nil }
}

private actor BrowserRoundTripTransport: HTTPTransport {
    let retryStarted: XCTestExpectation
    private(set) var codeRequests = 0
    private var polls = 0
    private var initialPollWaiter: CheckedContinuation<Void, Never>?
    private var interruption: CheckedContinuation<Void, Never>?
    private var approval: CheckedContinuation<Void, Never>?

    init(retryStarted: XCTestExpectation) { self.retryStarted = retryStarted }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let object: [String: Any]
        switch request.url?.path {
        case "/api/accounts/deviceauth/usercode":
            codeRequests += 1
            object = ["device_auth_id": UUID().uuidString, "user_code": "TEST-CODE", "interval": "5"]
        case "/api/accounts/deviceauth/token":
            polls += 1
            if polls == 1 {
                await withCheckedContinuation {
                    interruption = $0
                    initialPollWaiter?.resume(); initialPollWaiter = nil
                }
                throw URLError(.cancelled)
            }
            await withCheckedContinuation {
                approval = $0
                retryStarted.fulfill()
            }
            object = ["authorization_code": "synthetic-code", "code_verifier": String(repeating: "v", count: 43),
                      "code_challenge": String(repeating: "c", count: 43)]
        case "/oauth/token":
            let claims = try JSONSerialization.data(withJSONObject: ["https://api.openai.com/auth": ["chatgpt_account_id": "synthetic-account"]])
            let payload = claims.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
            object = ["access_token": UUID().uuidString, "refresh_token": UUID().uuidString,
                      "id_token": "e30.\(payload).synthetic-signature", "expires_in": 3600]
        case "/backend-api/wham/usage":
            object = ["rate_limit": ["primary_window": ["used_percent": 25]]]
        default: throw URLError(.badURL)
        }
        return HTTPResponse(data: try JSONSerialization.data(withJSONObject: object), statusCode: 200, retryAfter: nil)
    }

    func waitForInitialPoll() async {
        if interruption != nil { return }
        await withCheckedContinuation { initialPollWaiter = $0 }
    }
    func interruptPoll() { interruption?.resume(); interruption = nil }
    func approve() { approval?.resume(); approval = nil }
}
