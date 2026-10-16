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

    func testCaptureHomeWidget() throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == "Mana App Store Assets" else {
            throw XCTSkip("Shared Demo widget capture requires the dedicated credential-free asset simulator.")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Demo • Sample data"].firstMatch.waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if !springboard.staticTexts["DEMO · SAMPLE"].exists {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(forDuration: 2)
            springboard.buttons["Edit"].tap()
            springboard.buttons["Add Widget"].tap()
            let search = springboard.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            search.typeText("Mana")
            if springboard.buttons["Continue"].exists { springboard.buttons["Continue"].tap() }
            springboard.cells["Mana"].tap()
            // SpringBoard's widget gallery hierarchy can stall XCTest on iOS 26.
            // Tap the native gallery's Add Widget and Home Screen Done positions.
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.915)).tap()
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.81, dy: 0.035)).tap()
        }
        XCTAssertTrue(springboard.staticTexts["DEMO · SAMPLE"].waitForExistence(timeout: 15))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "app-store-home-widget"
        attachment.lifetime = .keepAlways
        add(attachment)
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
