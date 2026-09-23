import Foundation

enum ProviderID: String, CaseIterable, Identifiable, Sendable {
    case codex
    case openCodeGo

    var id: String { rawValue }
    var displayName: String { self == .codex ? "Codex" : "OpenCode Go" }
}

enum WindowContent: Equatable, Sendable {
    case percent(Double)
    case unknownPercent
    case blocked(String)
    case missing
}

struct UsageWindow: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let content: WindowContent
    let resetAt: Date?
    let resetText: String?
}

struct ProviderSnapshot: Equatable, Sendable {
    let provider: ProviderID
    let windows: [UsageWindow]
    let isBlocked: Bool
    let blockedReason: String?
    let receivedAt: Date

    var displayWindows: [UsageWindow] { windows.filter { $0.content != .missing } }
}

enum ProviderRequestState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(ProviderError)
}

struct ProviderUsageState: Equatable, Sendable {
    let provider: ProviderID
    var requestState: ProviderRequestState = .idle
    var snapshot: ProviderSnapshot?
    var lastAttemptAt: Date?
    var lastSuccessAt: Date?
    var lastError: ProviderError?
    var retryNotBefore: Date?

    var isStale: Bool { snapshot != nil && lastError != nil }
}
