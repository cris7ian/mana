import AppKit
import Combine
import Foundation

@MainActor
final class UsageRefreshCoordinator: ObservableObject {
    @Published private(set) var states: [ProviderID: ProviderUsageState] = Dictionary(
        uniqueKeysWithValues: ProviderID.allCases.map { ($0, ProviderUsageState(provider: $0)) }
    )

    private let providers: [ProviderID: any UsageProviding]
    private let settings: UsageSettings
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Duration) async throws -> Void
    private var schedulerTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private var inFlight: Set<ProviderID> = []
    private var stateGeneration: [ProviderID: Int] = [:]

    init(
        providers: [any UsageProviding],
        settings: UsageSettings,
        now: @escaping @Sendable () -> Date = Date.init,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.provider, $0) })
        self.settings = settings
        self.now = now
        self.sleep = sleep
    }

    func start() {
        guard schedulerTask == nil else { return }
        installWakeObserver()
        Task { await refreshAll(trigger: .launch) }
        scheduleLoop()
    }

    func stop() {
        schedulerTask?.cancel()
        schedulerTask = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    func reschedule() {
        guard schedulerTask != nil else { return }
        schedulerTask?.cancel()
        scheduleLoop()
    }

    func refreshAll(trigger: RefreshTrigger = .manual) async {
        async let codex: Void = refresh(.codex, trigger: trigger)
        async let go: Void = refresh(.openCodeGo, trigger: trigger)
        _ = await (codex, go)
    }

    func refresh(_ providerID: ProviderID, trigger: RefreshTrigger = .manual) async {
        guard !inFlight.contains(providerID), let provider = providers[providerID] else { return }
        if trigger == .automatic,
           let retryDate = states[providerID]?.retryNotBefore,
           now() < retryDate { return }

        inFlight.insert(providerID)
        var state = states[providerID] ?? ProviderUsageState(provider: providerID)
        state.requestState = .loading
        state.lastAttemptAt = now()
        states[providerID] = state
        let generation = stateGeneration[providerID, default: 0]
        defer { inFlight.remove(providerID) }

        do {
            let snapshot = try await provider.fetchSnapshot()
            guard stateGeneration[providerID, default: 0] == generation else { return }
            var updated = states[providerID] ?? ProviderUsageState(provider: providerID)
            updated.snapshot = snapshot
            updated.requestState = .loaded
            updated.lastSuccessAt = snapshot.receivedAt
            updated.lastError = nil
            updated.retryNotBefore = nil
            states[providerID] = updated
        } catch {
            let typedError: ProviderError
            if let providerError = error as? ProviderError {
                typedError = providerError
            } else if error is CancellationError {
                typedError = .cancelled
            } else {
                typedError = .transport(ProviderError.transportDescription(for: error))
            }
            guard stateGeneration[providerID, default: 0] == generation else { return }
            var updated = states[providerID] ?? ProviderUsageState(provider: providerID)
            updated.requestState = .failed(typedError)
            updated.lastError = typedError
            if case .rateLimited(let interval) = typedError {
                updated.retryNotBefore = now().addingTimeInterval(interval ?? settings.refreshInterval)
            }
            states[providerID] = updated
        }
    }

    func clearSnapshot(for providerID: ProviderID) {
        stateGeneration[providerID, default: 0] += 1
        states[providerID] = ProviderUsageState(provider: providerID)
    }

    func handleWake() async {
        await refreshAll(trigger: .wake)
    }

    private func scheduleLoop() {
        schedulerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let interval = max(1, self.settings.refreshInterval)
                do { try await self.sleep(.milliseconds(Int64(interval * 1_000))) }
                catch { return }
                guard !Task.isCancelled else { return }
                await self.refreshAll(trigger: .automatic)
            }
        }
    }

    private func installWakeObserver() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.handleWake() }
        }
    }
}

enum RefreshTrigger: Equatable, Sendable {
    case launch
    case automatic
    case manual
    case wake
}
