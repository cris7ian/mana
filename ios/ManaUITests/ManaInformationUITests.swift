import XCTest

@MainActor
final class ManaInformationUITests: ManaUITestCase {
    func testEnglishLinks() { verify(language: "en", locale: "en_US", settings: "Settings", privacy: "Privacy policy", support: "Support") }
    func testGermanLinks() { verify(language: "de", locale: "de_DE", settings: "Einstellungen", privacy: "Datenschutzerklärung", support: "Support") }
    func testSpanishLinks() { verify(language: "es", locale: "es_ES", settings: "Ajustes", privacy: "Política de privacidad", support: "Soporte") }
    func testFrenchLinks() { verify(language: "fr", locale: "fr_FR", settings: "Réglages", privacy: "Politique de confidentialité", support: "Assistance") }
    func testLinksRemainReachableWithAccessibilityTextSize() {
        verify(language: "en", locale: "en_US", settings: "Settings", privacy: "Privacy policy", support: "Support",
               arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    }

    private func verify(language: String, locale: String, settings: String, privacy: String, support: String, arguments: [String] = []) {
        let app = launch(arguments: arguments, language: language, locale: locale)
        app.tabBars.buttons[settings].tap()
        // Query any element type: SwiftUI exposes Link as a button on current iOS.
        let privacyLink = app.descendants(matching: .any)["privacy-policy-link"].firstMatch
        let supportLink = app.descendants(matching: .any)["support-link"].firstMatch
        scrollTo(privacyLink, in: app)
        XCTAssertEqual(privacyLink.label, privacy)
        XCTAssertTrue(privacyLink.isEnabled)
        scrollTo(supportLink, in: app)
        XCTAssertEqual(supportLink.label, support)
        XCTAssertTrue(supportLink.isEnabled)
        // Do not open unpublished pages or leave this credential-isolated runtime.
        attachScreenshot(app, name: "\(language) – Support and privacy links")
        app.terminate()
    }
}
