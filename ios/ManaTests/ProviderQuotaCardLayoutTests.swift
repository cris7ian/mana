import XCTest
import SwiftUI
import ManaCore
@testable import ManaIOS

@MainActor
final class ProviderQuotaCardLayoutTests: XCTestCase {
    func testRefreshingDoesNotChangeCardHeight() {
        let snapshot = ProviderSnapshot(provider: .codex, windows: [
            .init(id: "five-hour", label: "5h", content: .percent(50), resetAt: nil, resetText: nil)
        ], isBlocked: false, blockedReason: nil, receivedAt: .now)
        for record in [MobileProviderRecord(isConfigured: true),
                       MobileProviderRecord(isConfigured: true, snapshot: snapshot)] {
            for size in [DynamicTypeSize.large, .accessibility3] {
                for width in [320.0, 440.0] {
                    let idle = height(record: record, loading: false, size: size, width: width)
                    let loading = height(record: record, loading: true, size: size, width: width)
                    XCTAssertGreaterThan(idle, 0)
                    XCTAssertEqual(idle, loading, accuracy: 0.5,
                                   "Refresh changed height at width \(width), text size \(size)")
                }
            }
        }
    }

    func testRefreshingFooterScreenshot() {
        let record = MobileProviderRecord(isConfigured: true, snapshot: .init(
            provider: .codex, windows: [
                .init(id: "five-hour", label: "5h", content: .percent(50), resetAt: nil, resetText: nil)
            ], isBlocked: false, blockedReason: nil, receivedAt: .now))
        let host = UIHostingController(rootView:
            ProviderQuotaCard(provider: .codex, record: record, isLoading: true, isDemo: false))
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 440, height: 420)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "refreshing-footer-native-layout"
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
    }

    private func height(record: MobileProviderRecord, loading: Bool,
                        size: DynamicTypeSize, width: Double) -> CGFloat {
        let host = UIHostingController(rootView:
            ProviderQuotaCard(provider: .codex, record: record, isLoading: loading, isDemo: false)
                .environment(\.dynamicTypeSize, size))
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }
}
