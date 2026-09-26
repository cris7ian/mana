import AppKit
import SwiftUI

struct UsagePopoverView: View {
    @EnvironmentObject private var coordinator: UsageRefreshCoordinator
    @EnvironmentObject private var settings: UsageSettings
    @Environment(\.dismiss) private var dismiss
    let openSettings: () -> Void
    @State private var optionPressed = false
    @State private var modifierMonitor: Any?

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
                    if let lastUpdated {
                        HStack(spacing: 3) {
                            Text("Updated")
                            Text(lastUpdated, format: .dateTime.hour().minute())
                        }
                        .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Live usage")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !settings.visibleProviders.isEmpty {
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
            }
            .padding(.bottom, 14)

            if settings.visibleProviders.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No providers configured")
                        .font(.subheadline.weight(.semibold))
                    Text("Connect a provider to see usage here.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        dismiss()
                        openSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(settings.visibleProviders.enumerated()), id: \.element.id) { index, provider in
                    providerSection(provider)
                    if index < settings.visibleProviders.count - 1 {
                        Divider().padding(.vertical, 12)
                    }
                }
            }

            Divider().padding(.top, 12).padding(.bottom, 8)
            HStack(spacing: 14) {
                if !settings.visibleProviders.isEmpty {
                    Button {
                        dismiss()
                        openSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.plain)
                }
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
        .onAppear {
            optionPressed = NSEvent.modifierFlags.contains(.option)
            guard modifierMonitor == nil else { return }
            modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                optionPressed = event.modifierFlags.contains(.option)
                return event
            }
        }
        .onDisappear {
            if let modifierMonitor { NSEvent.removeMonitor(modifierMonitor) }
            modifierMonitor = nil
            optionPressed = false
        }
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
            statusPill("Stale", color: .orange)
        } else if state.requestState == .loading {
            ProgressView().controlSize(.mini)
        } else if state.snapshot != nil {
            statusPill("Current", color: .green)
        } else if state.lastError != nil {
            statusPill("Offline", color: .secondary)
        }
    }

    private func statusPill(_ title: String, color: Color) -> some View {
        Text(LocalizedStringKey(title))
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
    }

    private func missingOrError(_ error: ProviderError) -> some View {
        Text(error.localizedDescription)
            .font(.caption).foregroundStyle(.secondary)
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
                ResetTimeView(resetAt: resetAt, showDateForOption: optionPressed)
            } else if let resetText = window.resetText {
                HStack(spacing: 4) {
                    Text("Reset:")
                    Text(resetText)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ResetTimeView: View {
    let resetAt: Date
    let showDateForOption: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Label("Resets", systemImage: "clock")
            if isHovered || showDateForOption {
                Text(resetAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(ResetCountdown.text(until: resetAt, now: context.date))
                }
            }
        }
        .font(.caption2).foregroundStyle(.secondary)
        .onHover { isHovered = $0 }
        .help(Text(resetAt, format: .dateTime.month(.abbreviated).day().year().hour().minute()))
    }
}

enum ResetCountdown {
    static func text(until resetAt: Date, now: Date) -> String {
        let seconds = resetAt.timeIntervalSince(now)
        guard seconds > 0 else { return NSLocalizedString("Reset due", comment: "Reset time has passed") }

        if seconds >= 86_400 {
            let days = Int(seconds / 86_400)
            let hours = Int((seconds - Double(days * 86_400)) / 3_600)
            return String(format: NSLocalizedString("%lldd %lldh", comment: "Days and hours until reset"), days, hours)
        }

        let hours = Int(seconds / 3_600)
        let minutes = min(59, Int(ceil((seconds - Double(hours * 3_600)) / 60)))
        return String(format: NSLocalizedString("%lldh %lldm", comment: "Hours and minutes until reset"), hours, minutes)
    }
}
