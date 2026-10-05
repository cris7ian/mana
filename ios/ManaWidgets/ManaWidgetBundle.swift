import AppIntents
import Foundation
import ManaCore
import SwiftUI
import WidgetKit

struct OverviewTimeline: TimelineProvider {
    func placeholder(in context: Context) -> ManaWidgetEntry { .init(date: .now, snapshot: .preview()) }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (ManaWidgetEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { let value = await WidgetRefresh.load(demo: WidgetRefresh.demoEnabled); completion(.init(date: value.date, snapshot: value)) }
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ManaWidgetEntry>) -> Void) {
        Task {
            let value = await WidgetRefresh.load(demo: WidgetRefresh.demoEnabled)
            completion(Timeline(entries: widgetEntries(value), policy: .after(WidgetPolicy.nextRefresh(value))))
        }
    }
}

@main
struct ManaWidgetBundle: WidgetBundle {
    var body: some Widget {
        ManaOverviewWidget()
        ManaProviderWidget()
        ManaGoWidget()
    }
}

struct ManaOverviewWidget: Widget {
    let kind = "ManaOverview"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OverviewTimeline()) { entry in
            OverviewWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Mana overview")
        .description("Codex and OpenCode Go quotas, together. Updates are best-effort.")
        .supportedFamilies([.systemMedium])
    }
}

struct ManaProviderWidget: Widget {
    let kind = "ManaProvider"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ProviderWidgetIntent.self, provider: ProviderTimeline<ProviderWidgetIntent>()) { entry in
            ProviderWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Codex quotas")
        .description("Codex quotas at a glance. Edit to change provider or Lock Screen quota.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct ManaGoWidget: Widget {
    let kind = "ManaOpenCodeGo"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: GoWidgetIntent.self, provider: ProviderTimeline<GoWidgetIntent>()) { entry in
            ProviderWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("OpenCode Go quotas")
        .description("OpenCode Go quotas at a glance. Edit to change provider or Lock Screen quota.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct OverviewWidgetView: View {
    let entry: ManaWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Mana", systemImage: "hexagon.fill").font(.headline)
                Spacer()
                Text(entry.snapshot.isDemo ? String(localized: "DEMO · SAMPLE") : String(localized: "QUOTAS")).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 16) {
                providerColumn(.codex)
                Divider()
                providerColumn(.openCodeGo)
            }
        }
        .widgetURL(URL(string: "mana://dashboard"))
    }

    private func providerColumn(_ provider: ProviderID) -> some View {
        let record = entry.snapshot.record(provider)
        return Link(destination: URL(string: "mana://provider/\(provider.rawValue)")!) {
            VStack(alignment: .leading, spacing: 5) {
                Text(provider.displayName).font(.caption.weight(.semibold))
                if let snapshot = record.snapshot {
                    ForEach(snapshot.displayWindows.prefix(3)) { window in
                        WidgetQuotaRow(window: window)
                    }
                    if record.isStale(now: entry.date) {
                        Text("Stale").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                } else {
                    Text(record.lastError == nil ? String(localized: "Connect in Mana") : String(localized: "Open Mana to retry")).font(.caption2).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).privacySensitive()
        }
    }

}

private struct ProviderWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ManaWidgetEntry
    private var record: MobileProviderRecord { entry.snapshot.record(entry.provider) }
    private var window: UsageWindow? { WidgetPolicy.window(record, provider: entry.provider, selection: entry.selection) }
    private var percent: Double? { window?.content.remainingPercent }
    private var prefix: String {
        let status = (entry.snapshot.isDemo ? String(localized: "Demo") + " · " : "")
            + (record.isStale(now: entry.date) ? String(localized: "Stale") + " · " : "")
        let fallback = entry.selection == "rolling" ? "5h" : entry.selection == "weekly" ? "week" : "month"
        return "\(status)\(entry.provider.displayName) · \(UsageLocalization.compactLabel(window?.label ?? fallback))"
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(verbatim: "\(prefix): \(percent.map { UsageLocalization.remaining($0) } ?? String(localized: "Open Mana"))")
            case .accessoryCircular:
                Gauge(value: percent ?? 0, in: 0...100) {
                    HStack(spacing: 1) {
                        if entry.snapshot.isDemo { Image(systemName: "flask") }
                        Text(verbatim: "\(entry.provider == .codex ? "Codex" : "Go") \(window.map { UsageLocalization.compactLabel($0.label) } ?? "—")")
                    }.font(.system(size: 9))
                } currentValueLabel: {
                    VStack(spacing: 0) {
                        Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                        if record.isStale(now: entry.date) {
                            Text("Stale").font(.system(size: 7, weight: .semibold))
                        }
                    }
                }.gaugeStyle(.accessoryCircular).accessibilityLabel(Text(verbatim: "\(prefix), \(percent.map { UsageLocalization.remaining($0, accessibility: true) } ?? String(localized: "Quota unavailable"))"))
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(prefix).font(.headline)
                    if let window { WidgetQuotaRow(window: window) } else { Text(record.isConfigured ? String(localized: "Quota unavailable") : String(localized: "Connect in Mana")).font(.caption) }
                }
            default:
                VStack(alignment: .leading, spacing: 8) {
                    Label(entry.provider.displayName, systemImage: "hexagon.fill").font(.caption.weight(.semibold))
                    if entry.snapshot.isDemo { Text("DEMO · SAMPLE DATA").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary) }
                    if let snapshot = record.snapshot {
                        ForEach(snapshot.displayWindows.prefix(3)) { window in WidgetQuotaRow(window: window) }
                        if record.isStale(now: entry.date) {
                            Text("Stale").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    } else { Text(record.lastError == nil ? String(localized: "Connect in Mana") : String(localized: "Open Mana to retry")).font(.caption).foregroundStyle(.secondary) }
                    Spacer(minLength: 0)
                }
            }
        }
        .privacySensitive()
        .widgetURL(URL(string: "mana://provider/\(entry.provider.rawValue)"))
    }
}

private struct WidgetQuotaRow: View {
    let window: UsageWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(UsageLocalization.compactLabel(window.label)).foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(window.content.remainingPercent.map { UsageLocalization.remaining($0) } ?? status).fontWeight(.semibold)
            }.font(.caption2).monospacedDigit()
            if let remaining = window.content.remainingPercent {
                ProgressView(value: remaining, total: 100).tint(remaining <= 20 ? .red : remaining <= 50 ? .orange : .teal)
            }
        }
    }
    private var status: String {
        if case .blocked = window.content { return String(localized: "Blocked") }
        return String(localized: "Unknown")
    }
}
