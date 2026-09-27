import Foundation
import Combine

@MainActor
final class UsageSettings: ObservableObject {
    static let defaultRefreshInterval: TimeInterval = 60
    static let supportedRefreshIntervals: [TimeInterval] = [30, 60, 120, 300]

    @Published var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Self.refreshIntervalKey) }
    }
    @Published private(set) var configuredProviders: Set<ProviderID>
    @Published var antigravityPath: String {
        didSet { defaults.set(antigravityPath, forKey: Self.antigravityPathKey) }
    }
    @Published var antigravityEnabled: Bool {
        didSet {
            defaults.set(antigravityEnabled, forKey: Self.antigravityEnabledKey)
            setProviderConfigured(.antigravity, isConfigured: antigravityEnabled)
        }
    }

    nonisolated static let antigravityPathKey = "antigravityExecutablePath"
    nonisolated static let antigravityEnabledKey = "antigravityEnabled"

    nonisolated static func configuredAntigravityPath(defaults: UserDefaults = .standard) -> String {
        if let saved = defaults.string(forKey: antigravityPathKey), !saved.isEmpty { return saved }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.local/bin/agy", "/opt/homebrew/bin/agy", "/usr/local/bin/agy"]
        return candidates.first(where: FileManager.default.isExecutableFile(atPath:)) ?? candidates[0]
    }

    var visibleProviders: [ProviderID] {
        ProviderID.allCases.filter(configuredProviders.contains)
    }

    static let refreshIntervalKey = "refreshIntervalSeconds"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, configuredProviders: Set<ProviderID> = []) {
        self.defaults = defaults
        self.configuredProviders = configuredProviders
        self.antigravityPath = Self.configuredAntigravityPath(defaults: defaults)
        self.antigravityEnabled = defaults.bool(forKey: Self.antigravityEnabledKey)
        let stored = defaults.double(forKey: Self.refreshIntervalKey)
        self.refreshInterval = stored > 0 ? stored : Self.defaultRefreshInterval
        if antigravityEnabled { self.configuredProviders.insert(.antigravity) }
    }

    func setProviderConfigured(_ provider: ProviderID, isConfigured: Bool) {
        if isConfigured {
            configuredProviders.insert(provider)
        } else {
            configuredProviders.remove(provider)
        }
    }
}
