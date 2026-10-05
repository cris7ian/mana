import SwiftUI
import ManaCore

struct ManaSettingsView: View {
    @ObservedObject var model: MobileAppModel
    let connect: (ProviderID) -> Void
    @State private var disconnectProvider: ProviderID?

    var body: some View {
        List {
            if model.isDemo { Section { DemoBanner().listRowInsets(EdgeInsets()) } }
            Section("Providers") {
                ForEach(MobileStore.providers) { provider in
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text(provider.displayName).font(.headline)
                        } icon: {
                            Image(provider.iconName).resizable().scaledToFit().frame(width: 28, height: 28)
                                .accessibilityHidden(true)
                        }
                        if model.isDemo {
                            Text("Demo • Sample data").font(.subheadline).foregroundStyle(.secondary)
                        } else if model.records[provider]?.isConfigured == true {
                            Text("Connected").font(.subheadline).foregroundStyle(.secondary)
                            Button("Disconnect \(provider.displayName)", role: .destructive) { disconnectProvider = provider }
                        } else {
                            Button("Connect \(provider.displayName)") { connect(provider) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            if let error = model.serviceError {
                Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
            }
            Section("Refresh") {
                Label("Every minute while open", systemImage: "arrow.clockwise")
                Text("Updates every minute while Mana is open. iOS controls background and widget updates.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Label("Credentials stay on this device", systemImage: "lock.shield")
                Text("Credentials are stored in your iPhone’s Keychain. Mana saves only the latest usage, never a history. Disconnecting removes the saved credentials and usage.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Demo mode", isOn: Binding(get: { model.isDemo }, set: { enabled in
                    Task { await model.setDemo(enabled) }
                }))
                .accessibilityIdentifier("demo-toggle")
                .disabled(model.isSwitching)
            } header: {
                Text("Preview")
            } footer: {
                Text("Try Mana with sample data. Your accounts stay untouched.")
            }
            Section {
                HStack(spacing: 12) {
                    Image("ManaBrandIcon").resizable().scaledToFit().frame(width: 40, height: 40).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mana").font(.headline)
                        Text("Built by Cristian E. Caroli 🧙‍♂️").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Disconnect \(disconnectProvider?.displayName ?? String(localized: "provider"))?", isPresented: Binding(
            get: { disconnectProvider != nil }, set: { if !$0 { disconnectProvider = nil } }
        ), titleVisibility: .visible) {
            if let provider = disconnectProvider {
                Button("Disconnect", role: .destructive) { Task { await model.disconnect(provider) } }
            }
            Button("Cancel", role: .cancel) { disconnectProvider = nil }
        } message: {
            Text("This removes this provider’s credentials and cached quotas from your device and widgets.")
        }
    }
}
