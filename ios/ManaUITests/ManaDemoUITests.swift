import XCTest

@MainActor
final class ManaDemoUITests: ManaUITestCase {
    func testDemoSwitchReturnsToCredentialFreeWelcome() throws {
        let app = launch(demo: true)

        XCTAssertTrue(app.staticTexts["Demo • Sample data"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["provider-codex"].exists)
        XCTAssertTrue(app.buttons["provider-openCodeGo"].exists)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Demo • Sample data"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Disconnect Codex"].exists)
        XCTAssertFalse(app.buttons["Disconnect OpenCode Go"].exists)
        attachScreenshot(app, name: "Demo – Settings")

        setDemo(false, in: app)
        app.tabBars.buttons["Usage"].tap()
        XCTAssertTrue(app.staticTexts["welcome-title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Demo • Sample data"].exists)
        XCTAssertTrue(app.buttons["connect-codex"].exists)
        XCTAssertTrue(app.buttons["connect-openCodeGo"].exists)
        // The isolated test runtime never reads existing simulator accounts.
    }

    func testDarkDemoWithAccessibilityTextSize() throws {
        let app = launch(demo: true, arguments: ["--demo-dark",
                         "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["provider-codex"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "Demo – Dark Accessibility Usage")
        app.buttons["provider-codex"].tap()
        XCTAssertTrue(app.navigationBars["Codex"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "Demo – Dark Accessibility Codex")
        app.buttons["Done"].tap()
        app.tabBars.buttons["Settings"].tap()
        scrollTo(app.switches["demo-toggle"], in: app)
        XCTAssertTrue(app.switches["demo-toggle"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "Demo – Dark Accessibility Settings")
    }

    func testCodexApprovalSurvivesBackgroundRoundTrip() throws {
        let app = launch(arguments: ["--ui-testing-codex"])
        app.buttons["connect-codex"].tap()
        app.buttons["Get approval code"].tap()
        let code = app.staticTexts["codex-approval-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        XCTAssertEqual(code.label, "Approval code: TEST-CODE")
        XCTAssertTrue(app.staticTexts["Waiting for your approval…"].exists)

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(code.waitForExistence(timeout: 5),
                      "Returning from another app must preserve the same approval code")
        XCTAssertEqual(code.label, "Approval code: TEST-CODE")
        XCTAssertTrue(app.staticTexts["Waiting for your approval…"].exists)
        XCTAssertFalse(app.buttons["Get approval code"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["connect-codex"].waitForExistence(timeout: 5))
        app.buttons["connect-codex"].tap()
        XCTAssertTrue(app.buttons["Get approval code"].waitForExistence(timeout: 5),
                      "Explicit cancellation must still clear the approval intent")
    }

    func testCompactDashboardKeepsResetBesideQuotaHeading() throws {
        let app = launch(demo: true)
        XCTAssertTrue(app.buttons["provider-codex"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Mana"].exists)

        let heading = app.staticTexts["quota-heading-primary_window"]
        let reset = app.buttons["quota-reset-primary_window"]
        XCTAssertTrue(heading.exists)
        XCTAssertTrue(reset.exists)
        XCTAssertLessThan(abs(heading.frame.midY - reset.frame.midY), 10,
                          "The reset countdown belongs on the quota heading line")
        attachScreenshot(app, name: "Demo – Compact Quota Headings")
        reset.tap()
        XCTAssertTrue(app.staticTexts["Resets"].waitForExistence(timeout: 5),
                      "The compact countdown must still expose the full reset date")
    }

    func testDemoStartsOffAtBottomOfSettings() throws {
        let app = launch()
        XCTAssertFalse(app.staticTexts["Demo • Sample data"].exists)
        app.tabBars.buttons["Settings"].tap()
        let providers = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Providers'")).firstMatch
        XCTAssertTrue(providers.waitForExistence(timeout: 5))

        let demoToggle = app.switches["demo-toggle"]
        scrollTo(demoToggle, in: app)
        XCTAssertEqual(demoToggle.value as? String, "0")
        let footer = app.staticTexts["Built by Cristian E. Caroli 🧙‍♂️"]
        scrollTo(footer, in: app)
        XCTAssertGreaterThan(footer.frame.midY, demoToggle.frame.midY)
        attachScreenshot(app, name: "Settings – Demo Default Off")
    }
}
