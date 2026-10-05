import SwiftUI
import BackgroundTasks
import ManaCore

@main
struct ManaIOSApp: App {
    @StateObject private var model: MobileAppModel

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let simulateCodex = ProcessInfo.processInfo.arguments.contains("--ui-testing-codex")
            _model = StateObject(wrappedValue: MobileAppModel(
                demo: ProcessInfo.processInfo.arguments.contains("--demo"),
                runtimeFactory: { IsolatedUITestRuntime(simulateCodex: simulateCodex) }, saveDemo: { _ in }, reloadWidgets: {}))
            return
        }
        #endif
        let defaults = UserDefaults(suiteName: MobileStore.groupID)
        defaults?.register(defaults: [MobileAppModel.demoKey: false])
        let demo = ProcessInfo.processInfo.arguments.contains("--demo")
            || defaults?.bool(forKey: MobileAppModel.demoKey) == true
        _model = StateObject(wrappedValue: MobileAppModel(demo: demo))
    }

    var body: some Scene {
        WindowGroup {
            ManaRootView(model: model)
                .preferredColorScheme(model.isDemo && ProcessInfo.processInfo.arguments.contains("--demo-dark") ? .dark : nil)
        }
            .backgroundTask(.appRefresh(ManaBackgroundRefresh.identifier)) {
                await model.refresh()
                await MainActor.run {
                    ManaBackgroundRefresh.schedule(enabled: !model.isDemo && model.hasConnections)
                }
            }
    }
}

#if DEBUG
/// UI tests can leave Demo without touching existing simulator accounts or widgets.
private struct IsolatedUITestRuntime: MobileAppRuntime {
    let simulateCodex: Bool
    func read(_ provider: ProviderID) throws -> MobileProviderRecord { .init() }
    func refresh(_ provider: ProviderID, force: Bool) async throws -> MobileProviderRecord { .init() }
    func connectGo(_ key: String) async throws -> MobileProviderRecord { throw MobileStorageError.unavailable }
    func beginCodex() async throws -> CodexSignIn {
        guard simulateCodex else { throw MobileStorageError.unavailable }
        return CodexSignIn(authorization: DeviceAuthorization(userCode: "TEST-CODE",
            verificationURL: URL(string: "https://auth.openai.com/codex/device")!, deviceAuthID: UUID().uuidString,
            interval: 5, expiresAt: .now.addingTimeInterval(900)), generation: UUID())
    }
    func completeCodex(_ signIn: CodexSignIn) async throws -> MobileProviderRecord {
        guard simulateCodex else { throw MobileStorageError.unavailable }
        // No provider requests. Hold synthetic approval until the UI test cancels.
        try await Task.sleep(for: .seconds(900))
        throw CodexDeviceAuthError.expired
    }
    func disconnect(_ provider: ProviderID) async throws { }
}
#endif

@MainActor
enum ManaBackgroundRefresh {
    static let identifier = "com.salsaparapizza.mana.ios.refresh"

    static func schedule(enabled: Bool) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        guard enabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        // iOS chooses whether and when to run. Failure must not affect foreground usage.
        try? BGTaskScheduler.shared.submit(request)
    }
}
