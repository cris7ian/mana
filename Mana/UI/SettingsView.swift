import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: UsageRefreshCoordinator
    @EnvironmentObject private var settings: UsageSettings
    let transport: any HTTPTransport

    @State private var message: String?
    @State private var messageSucceeded = false
    @State private var testingProvider: ProviderID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "dial.medium")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mana Settings").font(.title3.weight(.semibold))
                        Text("Usage sources and refresh behavior")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 2)

                settingsCard(title: "PROVIDERS", systemImage: "square.stack.3d.up") {
                    VStack(spacing: 12) {
                        providerRow(
                            provider: .codex,
                            detail: "Pi or OpenCode · OAuth token and account ID",
                            symbol: "sparkles",
                            tint: .blue
                        ) { Task { await testCodex() } }
                        Divider().padding(.leading, 42)
                        providerRow(
                            provider: .openCodeGo,
                            detail: "OpenCode · Go API key",
                            symbol: "bolt.circle",
                            tint: .purple
                        ) { Task { await testGo() } }
                    }
                }

                settingsCard(title: "REFRESH", systemImage: "arrow.clockwise") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Automatic refresh").font(.subheadline.weight(.medium))
                            Text("Updates while Mana is running")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("Refresh interval", selection: $settings.refreshInterval) {
                            ForEach(UsageSettings.supportedRefreshIntervals, id: \.self) { interval in
                                Text("\(Int(interval)) sec").tag(interval)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .onChange(of: settings.refreshInterval) { _ in coordinator.reschedule() }
                    }
                }

                if let message {
                    Label(message, systemImage: messageSucceeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(messageSucceeded ? Color.green : Color.orange)
                        .padding(.horizontal, 2)
                }

                Label("Credentials are read from local auth files and never copied. Usage stays in memory.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 500, height: 560)
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .tracking(0.55)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                }
        }
    }

    private func providerRow(
        provider: ProviderID,
        detail: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.displayName).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(action: action) {
                if testingProvider == provider {
                    ProgressView().controlSize(.small).frame(width: 48)
                } else {
                    Text("Test").frame(width: 48)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(testingProvider != nil)
        }
    }

    private func testCodex() async {
        testingProvider = .codex
        defer { testingProvider = nil }
        do {
            let credentials = try ProviderCredentialLoader().codexCredentials()
            let data = try await CodexUsageClient(transport: transport).fetch(credentials: credentials)
            _ = try CodexUsageDecoder.decode(data)
            message = "Codex connection succeeded."
            messageSucceeded = true
        } catch let error as ProviderError {
            message = error.localizedDescription
            messageSucceeded = false
        } catch {
            message = "Codex connection failed. Check network access, then retry."
            messageSucceeded = false
        }
    }

    private func testGo() async {
        testingProvider = .openCodeGo
        defer { testingProvider = nil }
        do {
            let credentials = try ProviderCredentialLoader().openCodeGoCredentials()
            let data = try await OpenCodeGoUsageClient(transport: transport).fetch(credentials: credentials)
            _ = try OpenCodeGoUsageDecoder.decode(data)
            message = "OpenCode Go connection succeeded."
            messageSucceeded = true
        } catch let error as ProviderError {
            message = error.localizedDescription
            messageSucceeded = false
        } catch {
            message = "OpenCode Go connection failed. Check network access, then retry."
            messageSucceeded = false
        }
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
        if let window {
            window.contentViewController = NSHostingController(rootView: content)
        } else {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
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
