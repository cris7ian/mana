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

    var visibleProviders: [ProviderID] {
        ProviderID.allCases.filter(configuredProviders.contains)
    }

    static let refreshIntervalKey = "refreshIntervalSeconds"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, configuredProviders: Set<ProviderID> = []) {
        self.defaults = defaults
        self.configuredProviders = configuredProviders
        let stored = defaults.double(forKey: Self.refreshIntervalKey)
        self.refreshInterval = stored > 0 ? stored : Self.defaultRefreshInterval
    }

    func setProviderConfigured(_ provider: ProviderID, isConfigured: Bool) {
        if isConfigured {
            configuredProviders.insert(provider)
        } else {
            configuredProviders.remove(provider)
        }
    }
}
