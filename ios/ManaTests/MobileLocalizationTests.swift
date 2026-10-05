import Foundation
import XCTest
@testable import ManaIOS

final class MobileLocalizationTests: XCTestCase {
    func testAppAndWidgetPackageEverySupportedLanguage() throws {
        let widgetURL = Bundle.main.bundleURL.appendingPathComponent("PlugIns/ManaWidgets.appex")
        let widget = try XCTUnwrap(Bundle(url: widgetURL))
        for bundle in [Bundle.main, widget] {
            for (language, settings, provider) in [
                ("en", "Settings", "Provider"),
                ("de", "Einstellungen", "Anbieter"),
                ("es", "Ajustes", "Proveedor"),
                ("fr", "Réglages", "Fournisseur")
            ] {
                let path = try XCTUnwrap(bundle.path(forResource: language, ofType: "lproj"))
                let localizedBundle = try XCTUnwrap(Bundle(path: path))
                XCTAssertEqual(localizedBundle.localizedString(forKey: "Settings", value: nil, table: nil), settings)
                XCTAssertEqual(localizedBundle.localizedString(forKey: "Provider", value: nil, table: nil), provider)
            }
        }
    }
}
