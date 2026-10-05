import XCTest

/// Captures the real UI with synthetic quotas. Never connects a provider.
@MainActor
final class ManaAppStoreScreenshotTests: ManaUITestCase {
    func testCaptureLightScreens() throws {
        let app = launchDemo()
        capture(app, named: "usage-light")

        app.buttons["provider-codex"].tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Connect Codex"].exists, "Demo details must remain read-only")
        capture(app, named: "codex-light")
        app.buttons["Done"].tap()

        app.buttons["provider-openCodeGo"].tap()
        XCTAssertTrue(app.navigationBars["OpenCode Go"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Monthly quota"].exists)
        XCTAssertFalse(app.buttons["Connect OpenCode Go"].exists, "Demo details must remain read-only")
        capture(app, named: "opencode-light")
        app.buttons["Done"].tap()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture(app, named: "settings-light")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Credentials stay on this device"].waitForExistence(timeout: 5))
        capture(app, named: "privacy-light")
    }

    func testCaptureDarkScreens() throws {
        let app = launchDemo(dark: true)
        capture(app, named: "usage-dark")
        app.buttons["provider-codex"].tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 5))
        capture(app, named: "codex-dark")
    }

    private func launchDemo(dark: Bool = false) -> XCUIApplication {
        let app = launch(demo: true, arguments: dark ? ["--demo-dark"] : [])
        XCTAssertTrue(app.buttons["provider-codex"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Demo • Sample data"].firstMatch.exists)
        return app
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        attachScreenshot(app, name: "app-store-\(name)")
    }
}
