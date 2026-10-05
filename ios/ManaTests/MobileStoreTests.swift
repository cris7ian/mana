import Foundation
import ManaCore
import XCTest
@testable import ManaIOS

final class MobileStoreTests: XCTestCase {
    func testRecordFreshnessUsesAgeAndFetchFailuresWithoutInventingMissingQuota() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        var record = try XCTUnwrap(ManaDemo.records(now: now)[.codex])
        XCTAssertFalse(record.isStale(now: now.addingTimeInterval(900)))
        XCTAssertTrue(record.isStale(now: now.addingTimeInterval(901)))
        record.lastError = "Safe test error"
        XCTAssertTrue(record.isStale(now: now))
        record.snapshot = nil
        XCTAssertFalse(record.isStale(now: now))
    }

    func testKeychainRoundTripWithoutTouchingProviderAccounts() throws {
        let credentials = MobileKeychainStore()
        let account = "synthetic-storage-test-\(UUID().uuidString)"
        defer { try? credentials.remove(account) }
        try credentials.write(Data(UUID().uuidString.utf8), account: account)
        XCTAssertNotNil(try credentials.read(account))
        try credentials.remove(account)
        XCTAssertNil(try credentials.read(account))
    }

    func testDisconnectRemovesCredentialAndLatestUsage() async throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        try credentials.write(Data("synthetic-test-key".utf8), account: store.account(.openCodeGo))
        try store.write(try XCTUnwrap(ManaDemo.records()[.openCodeGo]), provider: .openCodeGo)
        try await store.disconnect(.openCodeGo)
        let result = try store.read(.openCodeGo)
        XCTAssertFalse(result.isConfigured)
        XCTAssertNil(result.snapshot)
        XCTAssertNil(try credentials.read(store.account(.openCodeGo)))
    }

    func testCorruptCacheDoesNotDeleteCredential() throws {
        let credentials = MemoryMobileCredentials()
        let store = makeTemporaryStore(credentials: credentials)
        try credentials.write(Data("synthetic-test-key".utf8), account: store.account(.openCodeGo))
        try store.write(MobileProviderRecord(isConfigured: true), provider: .openCodeGo)
        try Data("invalid cache".utf8).write(to: store.directory.appendingPathComponent("openCodeGo.json"))
        let recovered = try store.read(.openCodeGo)
        XCTAssertTrue(recovered.isConfigured)
        XCTAssertNil(recovered.snapshot)
        XCTAssertNotNil(try credentials.read(store.account(.openCodeGo)))
    }

    func testCacheStoresOnlyNormalizedBlockedStateAndNoResetText() throws {
        let store = makeTemporaryStore()
        let snapshot = ProviderSnapshot(provider: .openCodeGo, windows: [
            .init(id: "rolling", label: "5h", content: .blocked("arbitrary external status"), resetAt: nil, resetText: "arbitrary external reset")
        ], isBlocked: true, blockedReason: "arbitrary external reason", receivedAt: .now)
        try store.write(.init(isConfigured: true, snapshot: snapshot), provider: .openCodeGo)
        let cached = try XCTUnwrap(store.read(.openCodeGo).snapshot)
        XCTAssertEqual(cached.windows[0].content, .blocked("blocked"))
        XCTAssertNil(cached.windows[0].resetText)
        XCTAssertEqual(cached.blockedReason, "Provider quota is blocked.")
    }

    func testConcurrentStoreInstancesSerializeMutations() async throws {
        let credentials = MemoryMobileCredentials()
        let first = makeTemporaryStore(credentials: credentials)
        let second = MobileStore(directory: first.directory, credentials: credentials)
        try first.write(.init(isConfigured: true), provider: .openCodeGo)
        let gate = TestLockGate()
        let write = Task {
            try await first.withLock(.openCodeGo) {
                await gate.hold()
                var record = try first.read(.openCodeGo)
                record.lastError = "Safe test error"
                try first.write(record, provider: .openCodeGo)
            }
        }
        addTeardownBlock { await gate.release(); _ = try? await write.value }
        await gate.waitForEntry()
        // The second process must not mutate the record while the first owns its lock.
        do {
            try await second.withLock(.openCodeGo, timeout: 0) { XCTFail("Provider lock must remain exclusive") }
            XCTFail("A busy provider lock must time out")
        } catch MobileStorageError.busy { }
        await gate.release()
        try await write.value
        try await second.disconnect(.openCodeGo)
        XCTAssertFalse(try first.read(.openCodeGo).isConfigured)
    }

    func testProviderLocksDoNotBlockAnIndependentProvider() async throws {
        let store = makeTemporaryStore()
        let gate = TestLockGate()
        let first = Task { try await store.withLock(.codex) { await gate.hold() } }
        addTeardownBlock { await gate.release(); _ = try? await first.value }
        await gate.waitForEntry()
        let result = try await store.withLock(.openCodeGo, timeout: 0) { "Independent provider completed" }
        XCTAssertEqual(result, "Independent provider completed")
        await gate.release()
        try await first.value
    }
}
