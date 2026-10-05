import Foundation
import ManaCore
import XCTest
@testable import ManaIOS

final class MobileRuntimeTests: XCTestCase {
    func testRateLimitPreservesQuotaAndAlsoBlocksManualRetry() async throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        let now = Date(timeIntervalSince1970: 10_000)
        let demo = try XCTUnwrap(ManaDemo.records(now: now.addingTimeInterval(-120))[.openCodeGo])
        try store.write(demo, provider: .openCodeGo)
        try credentials.write(Data("synthetic-test-key".utf8), account: store.account(.openCodeGo))
        let transport = MobileQueueTransport([.init(data: Data(), statusCode: 429, retryAfter: 3_600)])
        let runtime = MobileUsageRuntime(store: store, transport: transport, now: { now })
        let first = try await runtime.refresh(.openCodeGo, force: true)
        XCTAssertEqual(first.snapshot, demo.snapshot)
        XCTAssertEqual(first.retryNotBefore, now.addingTimeInterval(3_600))
        XCTAssertNotNil(first.lastError)
        _ = try await runtime.refresh(.openCodeGo, force: true)
        let calls = await transport.count
        XCTAssertEqual(calls, 1)
    }

    func testCancelledFetchPreservesGoodCacheWithoutSavingFailure() async throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        let now = Date(timeIntervalSince1970: 10_000)
        let original = try XCTUnwrap(ManaDemo.records(now: now.addingTimeInterval(-120))[.openCodeGo])
        try store.write(original, provider: .openCodeGo)
        try credentials.write(Data(UUID().uuidString.utf8), account: store.account(.openCodeGo))
        let runtime = MobileUsageRuntime(store: store, transport: MobileCancelledTransport(), now: { now })
        do {
            _ = try await runtime.refresh(.openCodeGo, force: true)
            XCTFail("Cancelled fetch must remain cancellation")
        } catch is CancellationError { }
        XCTAssertEqual(try store.read(.openCodeGo), original)
    }

    func testDemoWidgetNeverConstructsLiveRuntime() async {
        let snapshot = await WidgetRefresh.load(demo: true, runtimeFactory: { XCTFail("Demo must not access live storage"); throw MobileStorageError.unavailable })
        XCTAssertTrue(snapshot.isDemo)
        XCTAssertEqual(snapshot.records.count, 2)
    }

    @MainActor
    func testAppDemoSelectionIsObservedByWidgetsWithoutLiveAccess() async {
        let defaults = UserDefaults(suiteName: MobileStore.groupID)!
        let previous = defaults.object(forKey: MobileAppModel.demoKey)
        defer {
            if let previous { defaults.set(previous, forKey: MobileAppModel.demoKey) }
            else { defaults.removeObject(forKey: MobileAppModel.demoKey) }
        }
        let model = MobileAppModel(demo: true, runtimeFactory: {
            XCTFail("App demo must not create live storage")
            throw MobileStorageError.unavailable
        }, reloadWidgets: {})
        XCTAssertTrue(model.isDemo)
        let snapshot = await WidgetRefresh.load(demo: WidgetRefresh.demoEnabled, runtimeFactory: {
            XCTFail("Widget demo must not create live storage")
            throw MobileStorageError.unavailable
        })
        XCTAssertTrue(snapshot.isDemo)
    }

    func testWidgetWaitingForLockCannotAccessLiveDataAfterDemoStarts() async throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        let now = Date(timeIntervalSince1970: 10_000)
        let original = try XCTUnwrap(ManaDemo.records(now: now.addingTimeInterval(-120))[.openCodeGo])
        try store.write(original, provider: .openCodeGo)
        try credentials.write(Data(UUID().uuidString.utf8), account: store.account(.openCodeGo))
        let gate = TestLockGate()
        let blocker = Task { try await store.withLock(.openCodeGo) { await gate.hold() } }
        await gate.waitForEntry()
        let flag = RuntimeDemoFlag()
        let transport = MobileQueueTransport([.init(data: Data(#"{"usage":{"rolling":{"status":"ok","percent":35}}}"#.utf8), statusCode: 200, retryAfter: nil)])
        let runtime = MobileUsageRuntime(store: store, transport: transport, now: { now })
        let widget = Task {
            await WidgetRefresh.load(demo: false, runtimeFactory: { runtime }, isDemoEnabled: { flag.value })
        }
        await Task.yield()
        flag.set(true)
        await gate.release()
        try await blocker.value
        let result = await widget.value
        XCTAssertTrue(result.isDemo)
        XCTAssertEqual(credentials.readCount, 0)
        let calls = await transport.count
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(try store.read(.openCodeGo), original)
    }

    func testWidgetExecutionDeadlineReturnsCacheWithoutReadingCredentials() async throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        let now = Date(timeIntervalSince1970: 10_000)
        let original = try XCTUnwrap(ManaDemo.records(now: now.addingTimeInterval(-120))[.openCodeGo])
        try store.write(original, provider: .openCodeGo)
        let gate = TestLockGate()
        let blocker = Task { try await store.withLock(.openCodeGo) { await gate.hold() } }
        await gate.waitForEntry()
        let transport = MobileQueueTransport([])
        let runtime = MobileUsageRuntime(store: store, transport: transport, now: { now })
        let result = await WidgetRefresh.load(demo: false, runtimeFactory: { runtime }, isDemoEnabled: { false }, executionBudget: .milliseconds(20))
        await gate.release()
        try await blocker.value
        XCTAssertFalse(result.isDemo)
        XCTAssertEqual(result.records[.openCodeGo]?.snapshot, original.snapshot)
        XCTAssertEqual(credentials.readCount, 0)
        let calls = await transport.count
        XCTAssertEqual(calls, 0)
    }
}

actor MobileQueueTransport: HTTPTransport {
    private var responses: [HTTPResponse]
    private(set) var count = 0
    init(_ responses: [HTTPResponse]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        count += 1
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }
}

private final class RuntimeDemoFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false
    var value: Bool { lock.withLock { enabled } }
    func set(_ value: Bool) { lock.withLock { enabled = value } }
}

private struct MobileCancelledTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse { throw URLError(.cancelled) }
}
