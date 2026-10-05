import SwiftUI
import ManaCore

struct ProviderConnectionView: View {
    @ObservedObject var model: MobileAppModel
    let provider: ProviderID
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @FocusState private var keyFocused: Bool

    private var isBusy: Bool { model.authProvider != nil }

    var body: some View {
        NavigationStack {
            Form {
                if model.isDemo {
                    Section { DemoBanner() }
                } else {
                    Section {
                        Label {
                            Text(provider.displayName).font(.headline)
                        } icon: {
                            Image(provider.iconName).resizable().scaledToFit().frame(width: 32, height: 32)
                                .accessibilityHidden(true)
                        }
                    }
                    if provider == .openCodeGo { goConnection }
                    else { codexConnection }
                    if let error = model.authError ?? model.serviceError {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("connection-error")
                        }
                    }
                    Section {
                        Label("Stored securely on this device", systemImage: "lock.shield")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Connect \(provider.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        apiKey = ""
                        Task { await model.cancelAuthentication(); dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(isBusy)
            .onChange(of: model.records[provider]?.generation) { _, _ in
                if !model.isDemo && model.records[provider]?.isConfigured == true && model.authError == nil { dismiss() }
            }
            .onDisappear {
                apiKey = ""
                // Opening the approval browser can make this view disappear.
                // Only explicit Cancel or a mode change should cancel sign-in.
            }
        }
    }

    private var goConnection: some View {
        Section {
            SecureField("OpenCode Go API key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($keyFocused)
                .submitLabel(.go)
                .onSubmit { connectKey() }
                .disabled(isBusy)
                .accessibilityIdentifier("opencode-key")
            Button(action: connectKey) {
                HStack {
                    Text(isBusy ? String(localized: "Testing key…") : String(localized: "Test and connect"))
                    if isBusy { Spacer(); ProgressView() }
                }
            }
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy || model.isSwitching)
        } header: {
            Text("API key")
        } footer: {
            Text("Enter your OpenCode Go API key. Mana checks it before saving it securely on your iPhone.")
        }
    }

    @ViewBuilder private var codexConnection: some View {
        if let signIn = model.signIn {
            Section {
                Text("Enter this code on OpenAI’s page, then come back to Mana.")
                Text(signIn.authorization.userCode)
                    .font(.title.monospaced().bold())
                    .textSelection(.enabled)
                    .accessibilityLabel("Approval code: \(signIn.authorization.userCode)")
                    .accessibilityIdentifier("codex-approval-code")
                Link("Open OpenAI", destination: signIn.authorization.verificationURL)
                    .font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date >= signIn.authorization.expiresAt ? String(localized: "Code expired. Cancel and start again.")
                         : String(localized: "Code expires in \(MobilePresentation.resetText(until: signIn.authorization.expiresAt, now: context.date))"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Label("Waiting for your approval…", systemImage: "clock")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Return to Mana after approval. Your code stays active until it expires.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } else {
            Section {
                Text("Sign in with OpenAI to connect Codex. Mana never asks for your password.")
                Button {
                    Task { await model.beginCodex() }
                } label: {
                    HStack {
                        Text(isBusy ? String(localized: "Requesting approval code…") : String(localized: "Get approval code"))
                        if isBusy { Spacer(); ProgressView() }
                    }
                }
                .disabled(isBusy || model.isSwitching)
            } footer: {
                Text("You choose when to open OpenAI and approve access. You can cancel at any time.")
            }
        }
    }

    private func connectKey() {
        guard !isBusy, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        keyFocused = false
        let key = apiKey
        apiKey = ""
        Task { await model.connectGo(key) }
    }
}
