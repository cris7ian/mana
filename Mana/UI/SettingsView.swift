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
                        Divider()
                        antigravityRow
                        Divider()
                        claudeManualRow
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
        .frame(width: 500, height: 680)
        .onAppear { openCodeKeyExists = credentialLoader.hasOpenCodeGoAPIKey() }
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringKey(title), systemImage: systemImage)
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
            Image("Provider-codex")
                .resizable().scaledToFit().frame(width: 21, height: 21)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text("OpenAI Codex").font(.subheadline.weight(.medium))
                if codexOAuth.isSignedIn {
                    Text("ChatGPT account connected")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Sign in with your ChatGPT account")
                        .font(.caption).foregroundStyle(.secondary)
                }
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
                Image("Provider-opencode")
                    .resizable().scaledToFit().frame(width: 21, height: 21)
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenCode Go").font(.subheadline.weight(.medium))
                    if openCodeKeyExists {
                        Text("API key saved in a private file")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Paste your OpenCode Go API key")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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

    private var antigravityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("Provider-antigravity")
                    .resizable().scaledToFit().frame(width: 20, height: 20)
                Text("Antigravity coding quota").font(.subheadline.weight(.medium))
                Spacer()
                Button("Test") { Task { await testAntigravity() } }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(testingProvider != nil)
                Toggle("Show", isOn: $settings.antigravityEnabled)
                    .labelsHidden()
                    .onChange(of: settings.antigravityEnabled) { enabled in
                        if enabled { Task { await coordinator.refresh(.antigravity) } }
                        else { coordinator.clearSnapshot(for: .antigravity) }
                    }
            }
            Text("Uses your signed-in agy CLI. No Google credentials are stored by Mana.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Absolute path to agy", text: $settings.antigravityPath)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
            Text("Antigravity's Claude/GPT quota is separate from your Claude subscription.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var claudeManualRow: some View {
        HStack {
            Image("Provider-claude")
                .resizable().scaledToFit().frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text("Claude subscription").font(.subheadline.weight(.medium))
                Text("Claude doesn't expose subscription usage to third-party apps. Check your usage in the browser.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Check in browser") {
                NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
    }

    private func testAntigravity() async {
        testingProvider = .antigravity
        defer { testingProvider = nil }
        do {
            _ = try await AntigravityUsageProvider(executablePath: { UsageSettings.configuredAntigravityPath() }).fetchSnapshot()
            message = String(localized: "Antigravity quota read succeeded.")
            messageSucceeded = true
            if settings.antigravityEnabled { await coordinator.refresh(.antigravity) }
        } catch {
            message = (error as? ProviderError)?.localizedDescription ?? String(localized: "Could not read agy usage.")
            messageSucceeded = false
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
            settings.setProviderConfigured(.codex, isConfigured: true)
            message = String(localized: "OpenAI sign-in succeeded.")
            messageSucceeded = true
            await coordinator.refresh(.codex)
        } catch {
            let safeError = (error as? LocalizedError)?.errorDescription
            message = safeError ?? String(localized: "OpenAI sign-in failed. Check network access and try again.")
            messageSucceeded = false
        }
    }

    private func signOutCodex() {
        do {
            try codexOAuth.signOut()
            settings.setProviderConfigured(.codex, isConfigured: false)
            coordinator.clearSnapshot(for: .codex)
            message = String(localized: "OpenAI credentials removed from a private file.")
            messageSucceeded = true
        } catch {
            message = String(localized: "Could not remove OpenAI credentials from a private file.")
            messageSucceeded = false
        }
    }

    private func saveOpenCodeKey() {
        do {
            try credentialLoader.saveOpenCodeGoAPIKey(openCodeKeyInput)
            settings.setProviderConfigured(.openCodeGo, isConfigured: true)
            openCodeKeyInput = ""
            isEditingOpenCodeKey = false
            openCodeKeyExists = true
            message = String(localized: "OpenCode Go API key saved in a private file.")
            messageSucceeded = true
            Task { await coordinator.refresh(.openCodeGo) }
        } catch {
            message = String(localized: "Could not save the OpenCode Go API key.")
            messageSucceeded = false
        }
    }

    private func removeOpenCodeKey() {
        do {
            try credentialLoader.removeOpenCodeGoAPIKey()
            settings.setProviderConfigured(.openCodeGo, isConfigured: false)
            openCodeKeyExists = false
            coordinator.clearSnapshot(for: .openCodeGo)
            message = String(localized: "OpenCode Go API key removed from a private file.")
            messageSucceeded = true
        } catch {
            message = String(localized: "Could not remove the OpenCode Go API key.")
            messageSucceeded = false
        }
    }

    private func copyOpenCodeKey() {
        do {
            guard let key = try credentialLoader.openCodeGoAPIKey() else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(key, forType: .string)
            message = String(localized: "OpenCode Go API key copied.")
            messageSucceeded = true
        } catch {
            message = String(localized: "Could not read the OpenCode Go API key from a private file.")
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
            message = String(localized: "Codex connection succeeded.")
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
            message = String(localized: "OpenCode Go connection succeeded.")
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
            newWindow.title = String(localized: "Mana Settings")
            newWindow.contentViewController = NSHostingController(rootView: content)
            newWindow.isReleasedWhenClosed = false
            newWindow.collectionBehavior = [.moveToActiveSpace]
            newWindow.delegate = self
            self.window = newWindow
        }
        guard let window else { return }
        window.setContentSize(NSSize(width: 540, height: 680))
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            window.setFrameOrigin(NSPoint(
                x: visibleFrame.midX - window.frame.width / 2,
                y: visibleFrame.midY - window.frame.height / 2
            ))
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        Task { @MainActor in NSApp.setActivationPolicy(.accessory) }
    }
}
