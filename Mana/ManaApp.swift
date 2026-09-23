import SwiftUI

@main
@MainActor
struct ManaApp: App {
    @StateObject private var settings: UsageSettings
    @StateObject private var coordinator: UsageRefreshCoordinator
    private let transport: URLSessionTransport

    init() {
        let settings = UsageSettings()
        let transport = URLSessionTransport()
        let coordinator = UsageRefreshCoordinator(
            providers: [
                CodexUsageProvider(transport: transport),
                OpenCodeGoUsageProvider(transport: transport)
            ],
            settings: settings
        )
        _settings = StateObject(wrappedValue: settings)
        _coordinator = StateObject(wrappedValue: coordinator)
        self.transport = transport
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            Task { @MainActor in coordinator.start() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView {
                SettingsWindowController.shared.show(coordinator: coordinator, settings: settings, transport: transport)
            }
                .environmentObject(coordinator)
                .environmentObject(settings)
        } label: {
            Image(systemName: "dial.medium")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(transport: transport)
                .environmentObject(coordinator)
                .environmentObject(settings)
                .frame(width: 480)
        }
    }
}
