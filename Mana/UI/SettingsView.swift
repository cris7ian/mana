import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: UsageRefreshCoordinator
    @EnvironmentObject private var settings: UsageSettings
    let transport: any HTTPTransport
    let credentialLoader: ProviderCredentialLoader
    let codexOAuth: CodexOAuthClient

    @State private var message: String?
    @State private var messageSucceeded = false
    @State private var testingProvider: ProviderID?
    @State private var isSigningIn = false
    @State private var isEditingOpenCodeKey = false
    @State private var openCodeKeyInput = ""
    @State private var openCodeKeyExists = false

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
                    VStack(alignment: .leading, spacing: 16) {
                        codexCredentialsRow
                        Divider()
                        openCodeCredentialsRow
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

                Label("OpenAI sign-in and the OpenCode Go key are stored in private files. Usage stays in memory.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 500, height: 560)
        .onAppear { openCodeKeyExists = credentialLoader.hasOpenCodeGoAPIKey() }
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

    private var codexCredentialsRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text("OpenAI Codex").font(.subheadline.weight(.medium))
                Text(codexOAuth.isSignedIn ? "ChatGPT account connected" : "Sign in with your ChatGPT account")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if codexOAuth.isSignedIn {
                Button("Test") { Task { await testCodex() } }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(testingProvider != nil || isSigningIn)
                Button("Sign out") { signOutCodex() }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(testingProvider != nil || isSigningIn)
            } else {
                Button {
                    Task { await signInCodex() }
                } label: {
                    if isSigningIn { ProgressView().controlSize(.small) }
                    else { Text("Sign in") }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSigningIn || testingProvider != nil)
            }
        }
    }

    private var openCodeCredentialsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.circle")
                    .foregroundStyle(.purple)
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenCode Go").font(.subheadline.weight(.medium))
                    Text(openCodeKeyExists ? "API key saved in a private file" : "Paste your OpenCode Go API key")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if openCodeKeyExists && !isEditingOpenCodeKey {
                    Button("Test") { Task { await testGo() } }
                        .buttonStyle(.bordered).controlSize(.small)
                        .disabled(testingProvider != nil || isSigningIn)
                }
            }

            if openCodeKeyExists && !isEditingOpenCodeKey {
                HStack(spacing: 8) {
                    Text(maskedOpenCodeKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.disabled)
                    Button {
                        copyOpenCodeKey()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy OpenCode Go API key")
                    .help("Copy API key")
                    Spacer()
                    Button("Replace") { isEditingOpenCodeKey = true }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button {
                        removeOpenCodeKey()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .help("Remove API key")
                }
            } else {
                HStack(spacing: 8) {
                    SecureField("OpenCode Go API key", text: $openCodeKeyInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") { saveOpenCodeKey() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(openCodeKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if openCodeKeyExists {
                        Button("Cancel") {
                            openCodeKeyInput = ""
                            isEditingOpenCodeKey = false
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
        }
    }

    private var maskedOpenCodeKey: String {
        guard let key = try? credentialLoader.openCodeGoAPIKey(), !key.isEmpty else { return "Key saved" }
        return String(key.prefix(6)) + String(repeating: "•", count: 6)
    }

    private func signInCodex() async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            try await codexOAuth.signIn()
            message = "OpenAI sign-in succeeded."
            messageSucceeded = true
            await coordinator.refresh(.codex)
        } catch {
            let safeError = (error as? LocalizedError)?.errorDescription
            message = safeError ?? "OpenAI sign-in failed. Check network access and try again."
            messageSucceeded = false
        }
    }

    private func signOutCodex() {
        do {
            try codexOAuth.signOut()
            coordinator.clearSnapshot(for: .codex)
            message = "OpenAI credentials removed from a private file."
            messageSucceeded = true
        } catch {
            message = "Could not remove OpenAI credentials from a private file."
            messageSucceeded = false
        }
    }

    private func saveOpenCodeKey() {
        do {
            try credentialLoader.saveOpenCodeGoAPIKey(openCodeKeyInput)
            openCodeKeyInput = ""
            isEditingOpenCodeKey = false
            openCodeKeyExists = true
            message = "OpenCode Go API key saved in a private file."
            messageSucceeded = true
            Task { await coordinator.refresh(.openCodeGo) }
        } catch {
            message = "Could not save the OpenCode Go API key."
            messageSucceeded = false
        }
    }

    private func removeOpenCodeKey() {
        do {
            try credentialLoader.removeOpenCodeGoAPIKey()
            openCodeKeyExists = false
            coordinator.clearSnapshot(for: .openCodeGo)
            message = "OpenCode Go API key removed from a private file."
            messageSucceeded = true
        } catch {
            message = "Could not remove the OpenCode Go API key."
            messageSucceeded = false
        }
    }

    private func copyOpenCodeKey() {
        do {
            guard let key = try credentialLoader.openCodeGoAPIKey() else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(key, forType: .string)
            message = "OpenCode Go API key copied."
            messageSucceeded = true
        } catch {
            message = "Could not read the OpenCode Go API key from a private file."
            messageSucceeded = false
        }
    }

    private func testCodex() async {
        testingProvider = .codex
        defer { testingProvider = nil }
        do {
            let credentials = try await codexOAuth.credentials()
            let data = try await CodexUsageClient(transport: transport).fetch(credentials: credentials)
            _ = try CodexUsageDecoder.decode(data)
            message = "Codex connection succeeded."
            messageSucceeded = true
            await coordinator.refresh(.codex)
        } catch let error as ProviderError {
            message = error.localizedDescription
            messageSucceeded = false
        } catch {
            message = error.localizedDescription
            messageSucceeded = false
        }
    }

    private func testGo() async {
        testingProvider = .openCodeGo
        defer { testingProvider = nil }
        do {
            let credentials = try credentialLoader.openCodeGoCredentials()
            let data = try await OpenCodeGoUsageClient(transport: transport).fetch(credentials: credentials)
            _ = try OpenCodeGoUsageDecoder.decode(data)
            message = "OpenCode Go connection succeeded."
            messageSucceeded = true
            await coordinator.refresh(.openCodeGo)
        } catch let error as ProviderError {
            message = error.localizedDescription
            messageSucceeded = false
        } catch {
            message = error.localizedDescription
            messageSucceeded = false
        }
    }
}


@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show(
        coordinator: UsageRefreshCoordinator,
        settings: UsageSettings,
        transport: any HTTPTransport,
        credentialLoader: ProviderCredentialLoader,
        codexOAuth: CodexOAuthClient
    ) {
        let content = SettingsView(transport: transport, credentialLoader: credentialLoader, codexOAuth: codexOAuth)
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
            newWindow.collectionBehavior = [.moveToActiveSpace]
            newWindow.delegate = self
            self.window = newWindow
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self, let window = self.window else { return }
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                let visibleFrame = screen.visibleFrame
                window.setFrameOrigin(NSPoint(
                    x: visibleFrame.midX - window.frame.width / 2,
                    y: visibleFrame.midY - window.frame.height / 2
                ))
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        Task { @MainActor in NSApp.setActivationPolicy(.accessory) }
    }
}
