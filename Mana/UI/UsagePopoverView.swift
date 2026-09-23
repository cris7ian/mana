import AppKit
import SwiftUI

struct UsagePopoverView: View {
    @EnvironmentObject private var coordinator: UsageRefreshCoordinator
    @Environment(\.dismiss) private var dismiss
    let openSettings: () -> Void

    private var lastUpdated: Date? {
        coordinator.states.values.compactMap(\.lastSuccessAt).max()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "dial.medium")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mana").font(.headline)
                    Text(lastUpdated.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? "Live usage")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await coordinator.refreshAll(trigger: .manual) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Refresh usage")
                .disabled(coordinator.states.values.contains { $0.requestState == .loading })
            }
            .padding(.bottom, 14)

            ForEach(Array(ProviderID.allCases.enumerated()), id: \.element.id) { index, provider in
                providerSection(provider)
                if index < ProviderID.allCases.count - 1 {
                    Divider().padding(.vertical, 12)
                }
            }

            Divider().padding(.top, 12).padding(.bottom, 8)
            HStack(spacing: 14) {
                Button {
                    dismiss()
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func providerSection(_ provider: ProviderID) -> some View {
        let state = coordinator.states[provider] ?? ProviderUsageState(provider: provider)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: provider == .codex ? "sparkles" : "bolt.circle")
                    .foregroundStyle(provider == .codex ? Color.blue : Color.purple)
                    .frame(width: 18)
                Text(provider.displayName.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                Spacer()
                providerStatus(state)
            }

            if let snapshot = state.snapshot {
                if snapshot.isBlocked, let reason = snapshot.blockedReason {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .padding(.leading, 26)
                }
                if snapshot.displayWindows.isEmpty {
                    Text("No active usage windows.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.leading, 26)
                } else {
                    ForEach(snapshot.displayWindows) { window in
                        windowRow(window).padding(.leading, 26)
                    }
                }
                if state.isStale, let error = state.lastError {
                    Label(error.localizedDescription, systemImage: "clock.arrow.circlepath")
                        .font(.caption2).foregroundStyle(.orange)
                        .padding(.leading, 26)
                }
            } else if case .failed(let error) = state.requestState {
                missingOrError(error)
                    .padding(.leading, 26)
            } else if state.requestState == .loading {
                Label("Connecting…", systemImage: "circle.dotted")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 26)
            } else {
                Text("Waiting for first refresh…")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 26)
            }
        }
    }

    @ViewBuilder
    private func providerStatus(_ state: ProviderUsageState) -> some View {
        if state.isStale {
            statusPill("STALE", color: .orange)
        } else if state.requestState == .loading {
            ProgressView().controlSize(.mini)
        } else if state.snapshot != nil {
            statusPill("CURRENT", color: .green)
        } else if state.lastError != nil {
            statusPill("OFFLINE", color: .secondary)
        }
    }

    private func statusPill(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
    }

    @ViewBuilder
    private func missingOrError(_ error: ProviderError) -> some View {
        if case .missingCredential = error {
            Text("Sign in with Pi or OpenCode. Mana reads their local auth files.")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Text(error.localizedDescription)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func windowRow(_ window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                switch window.content {
                case .percent(let percent):
                    Text("\(percent, specifier: "%.0f")%")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
                case .unknownPercent:
                    Text("Unknown").font(.caption).foregroundStyle(.secondary)
                case .blocked(let status):
                    Text(status.capitalized).font(.caption).foregroundStyle(.orange)
                case .missing:
                    EmptyView()
                }
            }
            if case .percent(let percent) = window.content {
                ProgressView(value: min(100, max(0, percent)), total: 100)
                    .controlSize(.mini)
                    .tint(percent >= 80 ? .red : (percent >= 50 ? .orange : .green))
            }
            if let resetAt = window.resetAt {
                Label("Resets \(resetAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if let resetText = window.resetText {
                Text("Reset: \(resetText)").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
