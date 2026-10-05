import Foundation

public enum ProviderID: String, CaseIterable, Identifiable, Codable, Sendable {
    case codex
    case openCodeGo
    case antigravity

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .openCodeGo: return "OpenCode Go"
        case .antigravity: return "Antigravity"
        }
    }

    public var iconName: String {
        switch self {
        case .codex: return "Provider-codex"
        case .openCodeGo: return "Provider-opencode"
        case .antigravity: return "Provider-antigravity"
        }
    }
}

public enum WindowContent: Codable, Equatable, Sendable {
    case percent(Double)
    case unknownPercent
    case blocked(String)
    case missing

    public var remainingPercent: Double? {
        guard case .percent(let usedPercent) = self, usedPercent.isFinite else { return nil }
        return 100 - min(max(usedPercent, 0), 100)
    }
}

public struct UsageWindow: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let content: WindowContent
    public let resetAt: Date?
    public let resetText: String?

    public init(id: String, label: String, content: WindowContent, resetAt: Date?, resetText: String?) {
        self.id = id
        self.label = label
        self.content = content
        self.resetAt = resetAt
        self.resetText = resetText
    }
}

public struct ProviderSnapshot: Codable, Equatable, Sendable {
    public let provider: ProviderID
    public let windows: [UsageWindow]
    public let isBlocked: Bool
    public let blockedReason: String?
    public let receivedAt: Date

    public init(provider: ProviderID, windows: [UsageWindow], isBlocked: Bool, blockedReason: String?, receivedAt: Date) {
        self.provider = provider
        self.windows = windows
        self.isBlocked = isBlocked
        self.blockedReason = blockedReason
        self.receivedAt = receivedAt
    }

    public var displayWindows: [UsageWindow] { windows.filter { $0.content != .missing } }
}

public enum ProviderRequestState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(ProviderError)
}

public struct ProviderUsageState: Equatable, Sendable {
    public let provider: ProviderID
    public var requestState: ProviderRequestState
    public var snapshot: ProviderSnapshot?
    public var lastAttemptAt: Date?
    public var lastSuccessAt: Date?
    public var lastError: ProviderError?
    public var retryNotBefore: Date?

    public init(provider: ProviderID, requestState: ProviderRequestState = .idle,
                snapshot: ProviderSnapshot? = nil, lastAttemptAt: Date? = nil,
                lastSuccessAt: Date? = nil, lastError: ProviderError? = nil,
                retryNotBefore: Date? = nil) {
        self.provider = provider
        self.requestState = requestState
        self.snapshot = snapshot
        self.lastAttemptAt = lastAttemptAt
        self.lastSuccessAt = lastSuccessAt
        self.lastError = lastError
        self.retryNotBefore = retryNotBefore
    }

    public var isStale: Bool { snapshot != nil && lastError != nil }
}
