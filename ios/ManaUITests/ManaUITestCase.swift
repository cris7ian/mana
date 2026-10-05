import XCTest

@MainActor
class ManaUITestCase: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func launch(demo: Bool = false, arguments: [String] = [], language: String = "en", locale: String = "en_US") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + arguments
        if demo { app.launchArguments.append("--demo") }
        app.launch()
        return app
    }

    func setDemo(_ enabled: Bool, in app: XCUIApplication) {
        let toggle = app.switches["demo-toggle"]
        scrollTo(toggle, in: app)
        let value = enabled ? "1" : "0"
        if toggle.value as? String != value {
            // SwiftUI exposes the whole row as a switch; tap its trailing thumb.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "The requested settings control must remain reachable")
    }

    func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
