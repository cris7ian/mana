import SwiftUI
import AppKit

struct UsagePopoverView: View {
    @EnvironmentObject private var coordinator: UsageRefreshCoordinator
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Mana", systemImage: "dial.medium")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await coordinator.refreshAll(trigger: .manual) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh usage")
                .disabled(coordinator.states.values.contains { $0.requestState == .loading })
            }

            ForEach(ProviderID.allCases) { provider in
                providerSection(provider)
                if provider != ProviderID.allCases.last { Divider() }
            }

            HStack {
                Button("Settings…", action: openSettings)
                    .buttonStyle(.link)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.link)
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 360)
    }

    @ViewBuilder
    private func providerSection(_ provider: ProviderID) -> some View {
        let state = coordinator.states[provider] ?? ProviderUsageState(provider: provider)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.displayName).font(.subheadline.weight(.semibold))
                Spacer()
                statusLabel(state)
            }
            if let snapshot = state.snapshot {
                if snapshot.isBlocked, let reason = snapshot.blockedReason {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                if snapshot.displayWindows.isEmpty {
                    Text("No active usage windows.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.displayWindows) { window in windowRow(window) }
                }
            } else if case .failed(let error) = state.requestState {
                missingOrError(provider: provider, error: error)
            } else if state.requestState == .loading {
                ProgressView("Loading usage…").controlSize(.small)
            } else {
                missingOrError(provider: provider, error: nil)
            }
            if let success = state.lastSuccessAt {
                Text("Last updated \(success.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if state.isStale, let error = state.lastError {
                Text("Stale · \(error.localizedDescription)")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func missingOrError(provider: ProviderID, error: ProviderError?) -> some View {
        if case .missingCredential = error {
            Text("Add the required credentials in Settings to view usage.")
                .font(.caption).foregroundStyle(.secondary)
        } else if let error {
            Text(error.localizedDescription).font(.caption).foregroundStyle(.secondary)
        } else {
            Text("Waiting for first refresh…").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func statusLabel(_ state: ProviderUsageState) -> some View {
        if state.isStale {
            Text("STALE").font(.caption2.weight(.bold)).foregroundStyle(.orange)
        } else if state.requestState == .loading {
            ProgressView().controlSize(.mini)
        } else if state.snapshot != nil {
            Text("CURRENT").font(.caption2.weight(.bold)).foregroundStyle(.green)
        } else if state.lastError != nil {
            Text("UNAVAILABLE").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func windowRow(_ window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label).font(.caption.weight(.medium))
                Spacer()
                switch window.content {
                case .percent(let percent): Text("\(percent, specifier: "%.0f")%")
                case .unknownPercent: Text("Unknown")
                case .blocked(let status): Text(status.capitalized).foregroundStyle(.orange)
                case .missing: Text("Unavailable").foregroundStyle(.secondary)
                }
            }
            if case .percent(let percent) = window.content {
                ProgressView(value: min(100, max(0, percent)), total: 100)
                    .tint(percent >= 80 ? .red : (percent >= 50 ? .orange : .green))
            }
            if let resetAt = window.resetAt {
                Text("Resets \(resetAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if let resetText = window.resetText {
                Text("Reset: \(resetText)").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
