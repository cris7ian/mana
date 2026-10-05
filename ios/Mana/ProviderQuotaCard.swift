import SwiftUI
import ManaCore

struct ProviderQuotaCard: View {
    let provider: ProviderID
    let record: MobileProviderRecord
    let isLoading: Bool
    let isDemo: Bool
    var details: (() -> Void)?
    var connect: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 18) {
                if let details {
                    Button(action: details) {
                        HStack {
                            heading
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isDemo ? String(localized: "\(provider.displayName) details, Demo, Sample data")
                                         : String(localized: "\(provider.displayName) details"))
                    .accessibilityIdentifier("provider-\(provider.rawValue)")
                } else { heading }
                if isDemo {
                    Text("Demo • Sample data").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                state(now: context.date)
                if let snapshot = record.snapshot {
                    if snapshot.displayWindows.isEmpty {
                        Text("Usage unavailable. Pull down to refresh.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(snapshot.displayWindows) { window in
                        QuotaWindowView(window: window, now: context.date, isDemo: isDemo)
                    }
                    if !isDemo {
                        Text("Updated \(snapshot.receivedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityLabel("Last updated \(snapshot.receivedAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                } else if record.isConfigured {
                    Text("Usage unavailable. Pull down to refresh.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(provider == .codex ? String(localized: "Connect with your OpenAI account.") : String(localized: "Connect with an OpenCode Go API key."))
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let connect, !isDemo {
                        Button("Connect \(provider.displayName)", action: connect)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("connect-\(provider.rawValue)")
                    }
                }
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        }
    }

    private var heading: some View {
        HStack(spacing: 12) {
            Image(provider.iconName)
                .resizable().scaledToFit().frame(width: 34, height: 34)
                .accessibilityHidden(true)
            Text(provider.displayName).font(.headline).foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder private func state(now: Date) -> some View {
        if isLoading { Label("Refreshing…", systemImage: "arrow.clockwise").font(.subheadline).foregroundStyle(.secondary) }
        if record.snapshot?.isBlocked == true {
            Label("Quota blocked", systemImage: "hand.raised.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
        }
        if !isDemo && record.isStale(now: now) {
            Label("Stale · Last saved usage", systemImage: "clock.badge.exclamationmark")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        if let error = record.lastError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        if let retry = record.retryNotBefore, retry > now {
            Text("Retry in \(MobilePresentation.resetText(until: retry, now: now))")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct QuotaWindowView: View {
    let window: UsageWindow
    let now: Date
    let isDemo: Bool
    @State private var showDate = false

    private var label: String {
        UsageLocalization.quotaLabel(window.label)
    }

    private var remaining: Double? { window.content.remainingPercent }
    private var meterColor: Color {
        guard let remaining else { return .secondary }
        return remaining <= 20 ? .red : remaining <= 50 ? .orange : .manaAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { heading; Spacer(minLength: 8); value }
                VStack(alignment: .leading, spacing: 4) { heading; value }
            }
            .font(.subheadline.weight(.medium))
            if let remaining {
                ProgressView(value: remaining, total: 100)
                    .tint(meterColor)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .popover(isPresented: $showDate) {
            if let reset = window.resetAt {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resets").font(.headline)
                    Text(reset.formatted(date: .abbreviated, time: .shortened))
                }
                .padding(20)
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .accessibilityIdentifier("quota-heading-\(window.id)")
                .accessibilityAddTraits(.isHeader)
            if let reset = window.resetAt {
                Button { showDate = true } label: {
                    Label(MobilePresentation.resetText(until: reset, now: now), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Resets \(reset.formatted(date: .abbreviated, time: .shortened))")
                .accessibilityHint("Show reset date and time")
                .accessibilityIdentifier("quota-reset-\(window.id)")
            } else {
                Text("Reset unknown").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var valueLabel: String {
        if let remaining { return UsageLocalization.remaining(remaining, accessibility: true) }
        if case .blocked = window.content { return String(localized: "Blocked") }
        return String(localized: "Unknown")
    }

    private var value: some View {
        Text(remaining.map { UsageLocalization.remaining($0) } ?? valueLabel)
            .monospacedDigit()
            .foregroundStyle(remaining == nil ? Color.secondary : meterColor)
            .accessibilityLabel(isDemo ? String(localized: "Demo, Sample data. \(valueLabel)") : valueLabel)
    }
}

struct ProviderDetailView: View {
    @ObservedObject var model: MobileAppModel
    let provider: ProviderID
    @Environment(\.dismiss) private var dismiss
    @State private var showConnection = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.isDemo { DemoBanner() }
                    ProviderQuotaCard(provider: provider, record: model.records[provider] ?? .init(),
                                      isLoading: model.loading.contains(provider), isDemo: model.isDemo,
                                      connect: { showConnection = true })
                    Text(model.isDemo ? String(localized: "These are synthetic quotas. Turn off demo in Settings to connect your own account.")
                         : String(localized: "Usage comes from your provider. If an update fails, Mana keeps the last saved values."))
                        .font(.footnote).foregroundStyle(.secondary)
                    if !model.isDemo && model.records[provider]?.isConfigured == true {
                        Button("Refresh usage", systemImage: "arrow.clockwise") { Task { await model.refresh(force: true) } }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(provider.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .refreshable { await model.refresh(force: true) }
            .sheet(isPresented: $showConnection) { ProviderConnectionView(model: model, provider: provider) }
        }
    }
}
