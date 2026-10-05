import Foundation
import Combine
import ManaCore
import WidgetKit

protocol MobileAppRuntime: Sendable {
    func read(_ provider: ProviderID) throws -> MobileProviderRecord
    func refresh(_ provider: ProviderID, force: Bool) async throws -> MobileProviderRecord
    func connectGo(_ key: String) async throws -> MobileProviderRecord
    func beginCodex() async throws -> CodexSignIn
    func completeCodex(_ signIn: CodexSignIn) async throws -> MobileProviderRecord
    func disconnect(_ provider: ProviderID) async throws
}

extension MobileUsageRuntime: MobileAppRuntime {
    func read(_ provider: ProviderID) throws -> MobileProviderRecord { try store.read(provider) }
}

@MainActor
final class MobileAppModel: ObservableObject {
    static let demoKey = "demoMode"
    @Published private(set) var isDemo: Bool
    @Published private(set) var records: [ProviderID: MobileProviderRecord] = [:]
    @Published private(set) var loading: Set<ProviderID> = []
    @Published private(set) var serviceError: String?
    @Published private(set) var isSwitching = false
    @Published private(set) var isActive = false
    @Published private(set) var signIn: CodexSignIn?
    @Published private(set) var authProvider: ProviderID?
    @Published private(set) var authError: String?

    private let runtimeFactory: () throws -> any MobileAppRuntime
    private let saveDemo: (Bool) -> Void
    private let reloadWidgets: () -> Void
    private let refreshInterval: Duration
    private var runtime: (any MobileAppRuntime)?
    private var generation = UUID()
    private var refreshTasks: [ProviderID: Task<Void, Never>] = [:]
    private var disconnectTasks: [ProviderID: Task<Void, Never>] = [:]
    private var authTask: Task<Void, Never>?
    private var ticker: Task<Void, Never>?

    var hasConnections: Bool { records.values.contains { $0.isConfigured } }

    init(demo: Bool = false, runtimeFactory: @escaping () throws -> any MobileAppRuntime = { try MobileUsageRuntime.live() },
         saveDemo: @escaping (Bool) -> Void = { UserDefaults(suiteName: MobileStore.groupID)?.set($0, forKey: demoKey) },
         reloadWidgets: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() },
         refreshInterval: Duration = .seconds(60)) {
        isDemo = demo
        self.runtimeFactory = runtimeFactory
        self.saveDemo = saveDemo
        self.reloadWidgets = reloadWidgets
        self.refreshInterval = refreshInterval
        if demo { records = ManaDemo.records() }
        else { loadLive() }
        // Persist only this preference. Sample snapshots never enter the shared cache.
        saveDemo(demo)
        reloadWidgets()
    }

    private func loadLive() {
        do {
            let live = try runtimeFactory()
            runtime = live
            serviceError = nil
            for provider in MobileStore.providers {
                do { records[provider] = try live.read(provider) }
                catch { records[provider] = .init(lastError: MobileUsageRuntime.safeMessage(error)) }
            }
        } catch {
            runtime = nil
            serviceError = MobileUsageRuntime.safeMessage(error)
        }
    }

    func setDemo(_ enabled: Bool) async {
        guard enabled != isDemo else { return }
        generation = UUID()
        let token = generation
        isSwitching = true
        isDemo = enabled
        records = enabled ? ManaDemo.records() : [:]
        serviceError = nil
        signIn = nil
        authError = nil
        loading = []
        saveDemo(enabled)
        reloadWidgets()
        ticker?.cancel()
        ticker = nil
        let pending = Array(refreshTasks.values) + Array(disconnectTasks.values) + [authTask].compactMap { $0 }
        pending.forEach { $0.cancel() }
        refreshTasks = [:]
        disconnectTasks = [:]
        authTask = nil
        authProvider = nil
        for task in pending { await task.value }
        guard generation == token else { return }
        runtime = nil
        if !enabled { loadLive() }
        isSwitching = false
        if isActive { startTicker() }
    }

    func refresh(force: Bool = false) async {
        guard !isDemo, !isSwitching, let runtime else { return }
        let token = generation
        for provider in MobileStore.providers where records[provider]?.isConfigured == true {
            guard refreshTasks[provider] == nil, disconnectTasks[provider] == nil, authProvider != provider else { continue }
            loading.insert(provider)
            refreshTasks[provider] = Task { [weak self] in
                do {
                    let record = try await runtime.refresh(provider, force: force)
                    guard !Task.isCancelled, let self, self.generation == token, !self.isDemo else { return }
                    self.records[provider] = record
                    self.reloadWidgets()
                } catch {
                    guard !Task.isCancelled, let self, self.generation == token, !self.isDemo else { return }
                    var record = self.records[provider] ?? .init()
                    record.lastError = MobileUsageRuntime.safeMessage(error)
                    self.records[provider] = record
                }
                guard let self, self.generation == token else { return }
                self.loading.remove(provider)
                self.refreshTasks[provider] = nil
            }
        }
        let pending = Array(refreshTasks.values)
        await withTaskCancellationHandler {
            for task in pending { await task.value }
        } onCancel: {
            pending.forEach { $0.cancel() }
        }
        if generation == token {
            // Cancellation leaves cached values intact and ends all progress indicators.
            for provider in MobileStore.providers where refreshTasks[provider]?.isCancelled == true {
                refreshTasks[provider] = nil
                loading.remove(provider)
            }
        }
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active { startTicker() }
        else {
            ticker?.cancel()
            ticker = nil
            refreshTasks.values.forEach { $0.cancel() }
        }
    }

    private func startTicker() {
        guard !isDemo, !isSwitching, ticker == nil else { return }
        ticker = Task { [weak self, refreshInterval] in
            await self?.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: refreshInterval) }
                catch { return }
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    func connectGo(_ key: String) async {
        guard !isDemo, !isSwitching, authTask == nil, disconnectTasks[.openCodeGo] == nil, let runtime else { return }
        await beginAuthentication(provider: .openCodeGo) { try await runtime.connectGo(key) }
    }

    func beginCodex() async {
        guard !isDemo, !isSwitching, authTask == nil, disconnectTasks[.codex] == nil, let runtime else { return }
        let token = generation
        await beginAuthentication(provider: .codex) { [weak self] in
            let signIn = try await runtime.beginCodex()
            try Task.checkCancellation()
            guard let self, self.generation == token, !self.isDemo else { throw CancellationError() }
            self.signIn = signIn
            return try await runtime.completeCodex(signIn)
        }
    }

    private func beginAuthentication(provider: ProviderID,
                                     operation: @escaping @MainActor () async throws -> MobileProviderRecord) async {
        let token = generation
        authError = nil
        authProvider = provider
        // Do not let a refresh of the old account overwrite a newly connected account.
        if let refresh = refreshTasks[provider] {
            refresh.cancel()
            await refresh.value
            refreshTasks[provider] = nil
            loading.remove(provider)
        }
        guard generation == token, !isDemo else { return }
        let task = Task { [weak self] in
            do {
                let record = try await operation()
                guard !Task.isCancelled, let self, self.generation == token, !self.isDemo else { return }
                self.records[provider] = record
                self.reloadWidgets()
            } catch {
                guard !Task.isCancelled, let self, self.generation == token, !self.isDemo else { return }
                // A quota failure must not hide an account whose approval was saved.
                if let runtime = self.runtime, let record = try? runtime.read(provider) {
                    self.records[provider] = record
                    self.reloadWidgets()
                }
                self.authError = MobileUsageRuntime.safeMessage(error)
            }
            guard let self, self.generation == token else { return }
            self.signIn = nil
            self.authProvider = nil
            self.authTask = nil
        }
        authTask = task
        await task.value
    }

    func cancelAuthentication() async {
        let token = generation
        let provider = authProvider
        let task = authTask
        task?.cancel()
        await task?.value
        guard generation == token else { return }
        // Approval can commit before the initial quota request is cancelled.
        // Keep that connection visible so Settings can disconnect it.
        if !isDemo, let provider, let runtime {
            do {
                records[provider] = try runtime.read(provider)
                reloadWidgets()
            } catch { serviceError = MobileUsageRuntime.safeMessage(error) }
        }
        signIn = nil
        authTask = nil
        authProvider = nil
        authError = nil
    }

    func disconnect(_ provider: ProviderID) async {
        guard !isDemo, !isSwitching, disconnectTasks[provider] == nil, let runtime else { return }
        let token = generation
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.generation == token { self.disconnectTasks[provider] = nil }
            }
            if self.authProvider == provider { await self.cancelAuthentication() }
            if let pending = self.refreshTasks[provider] {
                pending.cancel()
                await pending.value
                guard self.generation == token else { return }
                self.refreshTasks[provider] = nil
                self.loading.remove(provider)
            }
            guard !Task.isCancelled, self.generation == token, !self.isDemo else { return }
            do {
                try await runtime.disconnect(provider)
                guard self.generation == token, !self.isDemo else { return }
                self.records[provider] = .init()
                self.reloadWidgets()
            } catch {
                guard !Task.isCancelled, self.generation == token, !self.isDemo else { return }
                self.serviceError = MobileUsageRuntime.safeMessage(error)
            }
        }
        disconnectTasks[provider] = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }
}
