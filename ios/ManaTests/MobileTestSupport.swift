import Foundation
import XCTest
@testable import ManaIOS

extension XCTestCase {
    func makeTemporaryStore(credentials: any MobileCredentialStoring = MemoryMobileCredentials()) -> MobileStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return MobileStore(directory: directory, credentials: credentials)
    }
}

final class MemoryMobileCredentials: MobileCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    private var reads = 0
    var readCount: Int { lock.withLock { reads } }
    func read(_ account: String) throws -> Data? { lock.withLock { reads += 1; return values[account] } }
    func write(_ data: Data, account: String) throws { lock.withLock { values[account] = data } }
    func remove(_ account: String) throws { _ = lock.withLock { values.removeValue(forKey: account) } }
}

actor TestLockGate {
    private var entered = false
    private var released = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func hold() async {
        entered = true
        entryWaiters.forEach { $0.resume() }
        entryWaiters = []
        if released { return }
        await withCheckedContinuation { releaseWaiter = $0 }
    }

    func waitForEntry() async {
        if entered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func release() {
        released = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}
