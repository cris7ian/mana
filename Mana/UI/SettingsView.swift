import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: UsageRefreshCoordinator
    @EnvironmentObject private var settings: UsageSettings
    let transport: any HTTPTransport

    @State private var message: String?
    @State private var testingProvider: ProviderID?

    var body: some View {
        Form {
            Section("Credentials") {
                Text("Mana reads the same local Pi and OpenCode auth files as codexusage and gousage. It does not modify those files.")
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent("Codex", value: "Pi or OpenCode auth file")
                LabeledContent("OpenCode Go", value: "OpenCode auth file")
                HStack {
                    Button(testingProvider == .codex ? "Testing…" : "Test Codex") { Task { await testCodex() } }
                        .disabled(testingProvider != nil)
                    Button(testingProvider == .openCodeGo ? "Testing…" : "Test OpenCode Go") { Task { await testGo() } }
                        .disabled(testingProvider != nil)
                }
            }

            Section("Refresh") {
                Picker("Refresh interval", selection: $settings.refreshInterval) {
                    ForEach(UsageSettings.supportedRefreshIntervals, id: \.self) { interval in
                        Text("\(Int(interval)) seconds").tag(interval)
                    }
                }
                .onChange(of: settings.refreshInterval) { _ in coordinator.reschedule() }
            }

            if let message {
                Section { Text(message).font(.callout).textSelection(.enabled) }
            }
            Text("Mana keeps current usage in memory only. It does not save credentials or usage history.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testCodex() async {
        testingProvider = .codex
        defer { testingProvider = nil }
        do {
            let credentials = try ProviderCredentialLoader().codexCredentials()
            let data = try await CodexUsageClient(transport: transport).fetch(credentials: credentials)
            _ = try CodexUsageDecoder.decode(data)
            message = "Codex connection succeeded."
        } catch let error as ProviderError { message = error.localizedDescription }
        catch { message = "Codex connection failed. Check network access, then retry." }
    }

    private func testGo() async {
        testingProvider = .openCodeGo
        defer { testingProvider = nil }
        do {
            let credentials = try ProviderCredentialLoader().openCodeGoCredentials()
            let data = try await OpenCodeGoUsageClient(transport: transport).fetch(credentials: credentials)
            _ = try OpenCodeGoUsageDecoder.decode(data)
            message = "OpenCode Go connection succeeded."
        } catch let error as ProviderError { message = error.localizedDescription }
        catch { message = "OpenCode Go connection failed. Check network access, then retry." }
    }
}

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(coordinator: UsageRefreshCoordinator, settings: UsageSettings, transport: any HTTPTransport) {
        let content = SettingsView(transport: transport)
            .environmentObject(coordinator)
            .environmentObject(settings)
            .frame(width: 480)
        if let window {
            window.contentViewController = NSHostingController(rootView: content)
        } else {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "Mana Settings"
            newWindow.contentViewController = NSHostingController(rootView: content)
            newWindow.isReleasedWhenClosed = false
            self.window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
    }
}
