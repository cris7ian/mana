import XCTest

@MainActor
final class ManaLocalizationUITests: ManaUITestCase {
    func testGerman() { verify(language: "de", region: "de_DE", usage: "Nutzung", settings: "Einstellungen", demo: "Demo • Beispieldaten", weekly: "Wochenkontingent", done: "Fertig", connect: "OpenCode Go verbinden", cancel: "Abbrechen", key: "OpenCode-Go-API-Schlüssel") }
    func testSpanish() { verify(language: "es", region: "es_ES", usage: "Uso", settings: "Ajustes", demo: "Demo • Datos de ejemplo", weekly: "Cuota semanal", done: "Listo", connect: "Conectar OpenCode Go", cancel: "Cancelar", key: "Clave API de OpenCode Go") }
    func testFrench() { verify(language: "fr", region: "fr_FR", usage: "Utilisation", settings: "Réglages", demo: "Démo • Données d’exemple", weekly: "Quota hebdomadaire", done: "Terminé", connect: "Connecter OpenCode Go", cancel: "Annuler", key: "Clé API OpenCode Go") }
    func testUnsupportedLanguageFallsBackToEnglish() { verify(language: "ja", region: "ja_JP", usage: "Usage", settings: "Settings", demo: "Demo • Sample data", weekly: "Weekly quota", done: "Done", connect: "Connect OpenCode Go", cancel: "Cancel", key: "OpenCode Go API key") }

    private func verify(language: String, region: String, usage: String, settings: String, demo: String, weekly: String, done: String, connect: String, cancel: String, key: String) {
        let app = launch(demo: true, language: language, locale: region)
        XCTAssertTrue(app.staticTexts[demo].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons[usage].exists)
        app.buttons["provider-codex"].tap()
        XCTAssertTrue(app.staticTexts[weekly].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "\(language) – Codex quotas")
        app.buttons[done].tap()
        app.tabBars.buttons[settings].tap()
        XCTAssertTrue(app.navigationBars[settings].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "\(language) – Settings")
        setDemo(false, in: app)
        app.tabBars.buttons[usage].tap()
        app.buttons["connect-openCodeGo"].tap()
        XCTAssertTrue(app.navigationBars[connect].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields[key].exists)
        XCTAssertTrue(app.buttons[cancel].exists)
        attachScreenshot(app, name: "\(language) – Connect OpenCode Go")
        app.terminate()
    }
}
