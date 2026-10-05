import Foundation
import ManaCore

struct CodexSignIn: Sendable {
    let authorization: DeviceAuthorization
    let generation: UUID
}

struct MobileUsageRuntime: Sendable {
    let store: MobileStore
    let transport: any HTTPTransport
    let auth: CodexDeviceAuth
    let now: @Sendable () -> Date

    init(store: MobileStore, transport: any HTTPTransport = URLSessionTransport(), now: @escaping @Sendable () -> Date = Date.init,
         authSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.store = store
        self.transport = transport
        self.auth = CodexDeviceAuth(transport: transport, now: now, sleep: authSleep)
        self.now = now
    }

    static func live() throws -> MobileUsageRuntime { try MobileUsageRuntime(store: .live()) }

    func refresh(_ provider: ProviderID, force: Bool = false) async throws -> MobileProviderRecord {
        try await refresh(provider, force: force, allowLiveAccess: { true })
    }

    func refresh(_ provider: ProviderID, force: Bool,
                 allowLiveAccess: @escaping @Sendable () -> Bool) async throws -> MobileProviderRecord {
        try checkAccess(allowLiveAccess)
        return try await store.withLock(provider) {
            try checkAccess(allowLiveAccess)
            var record = try store.read(provider)
            guard record.isConfigured else { return record }
            if let retry = record.retryNotBefore, retry > now() { return record }
            // A foreground and widget request arriving together share the latest result.
            if !force, let snapshot = record.snapshot, record.lastError == nil,
               now().timeIntervalSince(snapshot.receivedAt) < 30 { return record }
            do {
                record.snapshot = try await fetch(provider, allowLiveAccess: allowLiveAccess)
                try checkAccess(allowLiveAccess)
                record.lastError = nil
                record.retryNotBefore = nil
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if Task.isCancelled || !allowLiveAccess() { throw CancellationError() }
                if case ProviderError.cancelled = error { throw CancellationError() }
                if (error as? URLError)?.code == .cancelled { throw CancellationError() }
                record.lastError = Self.safeMessage(error)
                if case ProviderError.rateLimited(let seconds) = error {
                    let maximum = Date.distantFuture.timeIntervalSince(now())
                    let bounded = seconds.flatMap { $0.isFinite && $0 >= 0 ? min($0, maximum) : nil } ?? 60
                    record.retryNotBefore = now().addingTimeInterval(max(1, bounded))
                }
            }
            try checkAccess(allowLiveAccess)
            try store.write(record, provider: provider)
            return record
        }
    }

    func refreshAll(allowLiveAccess: @escaping @Sendable () -> Bool = { true }) async -> [ProviderID: MobileProviderRecord] {
        await withTaskGroup(of: (ProviderID, MobileProviderRecord).self, returning: [ProviderID: MobileProviderRecord].self) { group in
            for provider in MobileStore.providers {
                group.addTask {
                    do { return (provider, try await refresh(provider, force: false, allowLiveAccess: allowLiveAccess)) }
                    catch {
                        if Task.isCancelled || !allowLiveAccess() { return (provider, MobileProviderRecord()) }
                        var record = (try? store.read(provider)) ?? MobileProviderRecord()
                        record.lastError = Self.safeMessage(error)
                        return (provider, record)
                    }
                }
            }
            var result: [ProviderID: MobileProviderRecord] = [:]
            for await (provider, record) in group { result[provider] = record }
            return result
        }
    }

    func connectGo(_ key: String) async throws -> MobileProviderRecord {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.utf8.count <= 16_384 else {
            throw ProviderError.missingCredential(provider: .openCodeGo, field: "API key")
        }
        return try await store.withLock(.openCodeGo) {
            let data = try await OpenCodeGoUsageClient(transport: transport).fetch(credentials: .init(apiKey: key))
            let snapshot = try OpenCodeGoUsageDecoder.decode(data, now: now())
            try Task.checkCancellation()
            var record = MobileProviderRecord()
            try store.write(record, provider: .openCodeGo)
            try store.credentials.write(Data(key.utf8), account: store.account(.openCodeGo))
            record.isConfigured = true
            record.snapshot = snapshot
            try store.write(record, provider: .openCodeGo)
            return record
        }
    }

    func beginCodex() async throws -> CodexSignIn {
        let generation = try await store.withLock(.codex) {
            let record = try store.read(.codex)
            try store.write(record, provider: .codex)
            return record.generation
        }
        return try await CodexSignIn(authorization: auth.begin(), generation: generation)
    }

    func completeCodex(_ signIn: CodexSignIn) async throws -> MobileProviderRecord {
        let tokens = try await auth.complete(signIn.authorization)
        try Task.checkCancellation()
        try await store.withLock(.codex) {
            guard try store.read(.codex).generation == signIn.generation else { throw MobileStorageError.accountChanged }
            var record = MobileProviderRecord()
            try store.write(record, provider: .codex)
            try store.credentials.write(JSONEncoder().encode(tokens), account: store.account(.codex))
            record.isConfigured = true
            try store.write(record, provider: .codex)
        }
        return try await refresh(.codex, force: true)
    }

    func disconnect(_ provider: ProviderID) async throws { try await store.disconnect(provider) }

    private func checkAccess(_ allowed: @Sendable () -> Bool) throws {
        try Task.checkCancellation()
        guard allowed() else { throw CancellationError() }
    }

    private func fetch(_ provider: ProviderID, allowLiveAccess: @Sendable () -> Bool) async throws -> ProviderSnapshot {
        try checkAccess(allowLiveAccess)
        guard let data = try store.credentials.read(store.account(provider)) else {
            throw ProviderError.missingCredential(provider: provider, field: provider == .codex ? "OpenAI sign-in" : "API key")
        }
        switch provider {
        case .codex:
            guard var tokens = try? JSONDecoder().decode(CodexMobileTokens.self, from: data),
                  !tokens.accessToken.isEmpty, !tokens.refreshToken.isEmpty, !tokens.accountID.isEmpty,
                  tokens.expiresAt.timeIntervalSince1970.isFinite else { throw MobileStorageError.invalidData }
            if tokens.expiresAt <= now().addingTimeInterval(60) {
                tokens = try await auth.refresh(tokens)
                try checkAccess(allowLiveAccess)
                // Persist rotated refresh tokens before any subsequent usage request.
                try store.credentials.write(JSONEncoder().encode(tokens), account: store.account(.codex))
            }
            try checkAccess(allowLiveAccess)
            let response = try await CodexUsageClient(transport: transport).fetch(credentials: .init(accessToken: tokens.accessToken, accountID: tokens.accountID))
            return try CodexUsageDecoder.decode(response, now: now())
        case .openCodeGo:
            try checkAccess(allowLiveAccess)
            guard let key = String(data: data, encoding: .utf8) else { throw MobileStorageError.invalidData }
            let response = try await OpenCodeGoUsageClient(transport: transport).fetch(credentials: .init(apiKey: key))
            return try OpenCodeGoUsageDecoder.decode(response, now: now())
        case .antigravity:
            throw MobileStorageError.invalidData
        }
    }

    static func safeMessage(_ error: Error) -> String {
        if let error = error as? MobileStorageError { return error.localizedDescription }
        if let error = error as? CodexDeviceAuthError { return error.localizedDescription }
        if let error = error as? ProviderError {
            if case .transport = error { return String(localized: "Network unavailable. Check your connection and try again.") }
            return error.localizedDescription
        }
        if error is CancellationError { return String(localized: "Refresh cancelled.") }
        return String(localized: "Could not connect to this provider. Check your connection and try again.")
    }
}
