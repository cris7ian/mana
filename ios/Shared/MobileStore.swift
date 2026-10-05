import Darwin
import Foundation
import ManaCore

struct MobileProviderRecord: Codable, Equatable, Sendable {
    var generation = UUID()
    var isConfigured = false
    var snapshot: ProviderSnapshot?
    var lastError: String?
    var retryNotBefore: Date?

    func isStale(now: Date = .now) -> Bool {
        guard let snapshot else { return false }
        return lastError != nil || MobilePresentation.isStale(receivedAt: snapshot.receivedAt, now: now)
    }
}

/// All app/extension credential mutations and fetches cross the same process-safe seam.
/// A per-provider advisory lock is held across network awaits and released on cancellation/crash.
struct MobileStore: Sendable {
    static let groupID = "group.com.salsaparapizza.mana.ios"
    static let providers: [ProviderID] = [.codex, .openCodeGo]
    let directory: URL
    let credentials: any MobileCredentialStoring

    init(directory: URL, credentials: any MobileCredentialStoring) {
        self.directory = directory
        self.credentials = credentials
    }

    static func live() throws -> MobileStore {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw MobileStorageError.unavailable
        }
        return MobileStore(directory: root.appendingPathComponent("LatestUsage", isDirectory: true), credentials: MobileKeychainStore())
    }

    func withLock<T: Sendable>(_ provider: ProviderID, timeout: TimeInterval = 20,
                               action: @Sendable () async throws -> T) async throws -> T {
        try prepareDirectory()
        let fd = open(directory.appendingPathComponent("\(provider.rawValue).lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw MobileStorageError.unavailable }
        defer { flock(fd, LOCK_UN); close(fd) }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(Int64(timeout * 1_000)))
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK, clock.now < deadline else { throw MobileStorageError.busy }
            try await Task.sleep(for: .milliseconds(50))
        }
        try Task.checkCancellation()
        return try await action()
    }

    func read(_ provider: ProviderID, recoverCredentialState: Bool = true) throws -> MobileProviderRecord {
        let url = recordURL(provider)
        guard FileManager.default.fileExists(atPath: url.path) else { return MobileProviderRecord() }
        let data = try Data(contentsOf: url)
        guard data.count <= 65_536 else { throw MobileStorageError.invalidData }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data), envelope.version == 1 else {
            // Corruption must not delete working credentials. Start with no cached usage.
            return MobileProviderRecord(isConfigured: recoverCredentialState ? try credentials.read(account(provider)) != nil : false)
        }
        if let snapshot = envelope.record.snapshot {
            guard snapshot.provider == provider, snapshot.receivedAt.timeIntervalSince1970.isFinite,
                  snapshot.windows.count <= 20,
                  snapshot.windows.allSatisfy({ window in
                      if case .percent(let value) = window.content { return value.isFinite }
                      return true
                  }) else { throw MobileStorageError.invalidData }
        }
        return envelope.record
    }

    func write(_ record: MobileProviderRecord, provider: ProviderID) throws {
        try prepareDirectory()
        // Never persist unstructured provider text. Only normalized windows and safe errors.
        var safe = record
        if let snapshot = record.snapshot {
            safe.snapshot = ProviderSnapshot(provider: snapshot.provider,
                windows: snapshot.windows.map {
                    let content: WindowContent
                    if case .blocked = $0.content { content = .blocked("blocked") } else { content = $0.content }
                    return UsageWindow(id: $0.id, label: $0.label, content: content, resetAt: $0.resetAt, resetText: nil)
                },
                isBlocked: snapshot.isBlocked, blockedReason: snapshot.isBlocked ? "Provider quota is blocked." : nil,
                receivedAt: snapshot.receivedAt)
        }
        let url = recordURL(provider)
        try JSONEncoder().encode(Envelope(version: 1, record: safe)).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func disconnect(_ provider: ProviderID) async throws {
        try await withLock(provider) {
            try Task.checkCancellation()
            // Write the tombstone first so a credential-delete failure cannot resurrect cached usage.
            try write(MobileProviderRecord(), provider: provider)
            try credentials.remove(account(provider))
        }
    }

    func account(_ provider: ProviderID) -> String {
        provider == .codex ? "codex-oauth" : "opencode-go-key"
    }

    private func recordURL(_ provider: ProviderID) -> URL { directory.appendingPathComponent("\(provider.rawValue).json") }
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var root = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
    }
    private struct Envelope: Codable { let version: Int; let record: MobileProviderRecord }
}
