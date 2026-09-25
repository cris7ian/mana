import SwiftUI

@MainActor
struct ManaApp: App {
    @StateObject private var settings: UsageSettings
    @StateObject private var coordinator: UsageRefreshCoordinator
    private let transport: URLSessionTransport
    private let credentialLoader: ProviderCredentialLoader
    private let codexOAuth: CodexOAuthClient

    init() {
        let transport = URLSessionTransport()
        let credentialStore = FileCredentialStore()
        let credentialLoader = ProviderCredentialLoader(store: credentialStore)
        let codexOAuth = CodexOAuthClient(store: credentialStore)
        let settings = UsageSettings(configuredProviders: Set(ProviderID.allCases.filter { provider in
            switch provider {
            case .codex: return codexOAuth.isSignedIn
            case .openCodeGo: return credentialLoader.hasOpenCodeGoAPIKey()
            }
        }))
        let coordinator = UsageRefreshCoordinator(
            providers: [
                CodexUsageProvider(oauth: codexOAuth, transport: transport),
                OpenCodeGoUsageProvider(loader: credentialLoader, transport: transport)
            ],
            settings: settings
        )
        _settings = StateObject(wrappedValue: settings)
        _coordinator = StateObject(wrappedValue: coordinator)
        self.transport = transport
        self.credentialLoader = credentialLoader
        self.codexOAuth = codexOAuth
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            Task { @MainActor in coordinator.start() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView {
                SettingsWindowController.shared.show(
                    coordinator: coordinator,
                    settings: settings,
                    transport: transport,
                    credentialLoader: credentialLoader,
                    codexOAuth: codexOAuth
                )
            }
                .environmentObject(coordinator)
                .environmentObject(settings)
        } label: {
            Image(systemName: "dial.medium")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(transport: transport, credentialLoader: credentialLoader, codexOAuth: codexOAuth)
                .environmentObject(coordinator)
                .environmentObject(settings)
                .frame(width: 480)
        }
    }
}
