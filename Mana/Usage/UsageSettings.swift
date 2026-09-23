import Foundation
import Combine

@MainActor
final class UsageSettings: ObservableObject {
    static let defaultRefreshInterval: TimeInterval = 60
    static let supportedRefreshIntervals: [TimeInterval] = [30, 60, 120, 300]

    @Published var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Self.refreshIntervalKey) }
    }

    static let refreshIntervalKey = "refreshIntervalSeconds"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: Self.refreshIntervalKey)
        self.refreshInterval = stored > 0 ? stored : Self.defaultRefreshInterval
    }
}
