import AppIntents
import Foundation
import ManaCore
import WidgetKit

enum WidgetProviderChoice: String, AppEnum {
    case codex, openCodeGo
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Provider"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.codex: "Codex", .openCodeGo: "OpenCode Go"]
    var provider: ProviderID { self == .codex ? .codex : .openCodeGo }
}

enum WidgetQuotaChoice: String, AppEnum {
    case fiveHour, weekly, monthly
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Quota window"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.fiveHour: "Five-hour", .weekly: "Weekly", .monthly: "Monthly (OpenCode Go)"]
    var selection: String { self == .fiveHour ? "rolling" : rawValue }
}

protocol ManaProviderWidgetIntent: WidgetConfigurationIntent {
    var provider: WidgetProviderChoice { get }
    var quota: WidgetQuotaChoice { get }
}

// Preserve the existing intent and widget kind so installed configurations still work.
struct ProviderWidgetIntent: ManaProviderWidgetIntent {
    static let title: LocalizedStringResource = "Mana quota"
    static let description = IntentDescription("Choose the provider and Lock Screen quota window.")
    @Parameter(title: "Provider", default: .codex) var provider: WidgetProviderChoice
    @Parameter(title: "Lock Screen quota", default: .fiveHour) var quota: WidgetQuotaChoice
}

struct GoWidgetIntent: ManaProviderWidgetIntent {
    static let title: LocalizedStringResource = "OpenCode Go quota"
    static let description = IntentDescription("Choose the provider and Lock Screen quota window.")
    @Parameter(title: "Provider", default: .openCodeGo) var provider: WidgetProviderChoice
    @Parameter(title: "Lock Screen quota", default: .fiveHour) var quota: WidgetQuotaChoice
}

struct ManaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    var provider: ProviderID = .codex
    var selection = "rolling"
}

func widgetEntries(_ snapshot: WidgetSnapshot, provider: ProviderID = .codex, selection: String = "rolling") -> [ManaWidgetEntry] {
    WidgetPolicy.timelineDates(snapshot).map { ManaWidgetEntry(date: $0, snapshot: snapshot, provider: provider, selection: selection) }
}

struct ProviderTimeline<Intent: ManaProviderWidgetIntent>: AppIntentTimelineProvider {
    static func preview(for configuration: Intent, now: Date = .now) -> ManaWidgetEntry {
        .init(date: now, snapshot: .preview(now: now), provider: configuration.provider.provider, selection: configuration.quota.selection)
    }

    func placeholder(in context: Context) -> ManaWidgetEntry { Self.preview(for: Intent()) }

    func snapshot(for configuration: Intent, in context: Context) async -> ManaWidgetEntry {
        if context.isPreview { return Self.preview(for: configuration) }
        let value = await WidgetRefresh.load(demo: WidgetRefresh.demoEnabled)
        return .init(date: value.date, snapshot: value, provider: configuration.provider.provider, selection: configuration.quota.selection)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<ManaWidgetEntry> {
        let value = await WidgetRefresh.load(demo: WidgetRefresh.demoEnabled)
        return Timeline(entries: widgetEntries(value, provider: configuration.provider.provider, selection: configuration.quota.selection), policy: .after(WidgetPolicy.nextRefresh(value)))
    }
}
