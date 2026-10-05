import Foundation
import XCTest
@testable import Mana

final class LocalizationTests: XCTestCase {
    func testAppPackagesEverySupportedLanguage() throws {
        let bundle = Bundle.main
        for (language, settings) in [("en", "Settings"), ("de", "Einstellungen"), ("es", "Ajustes"), ("fr", "Réglages")] {
            let path = try XCTUnwrap(bundle.path(forResource: language, ofType: "lproj"))
            let localizedBundle = try XCTUnwrap(Bundle(path: path))
            XCTAssertEqual(localizedBundle.localizedString(forKey: "Settings", value: nil, table: nil), settings)
            if language != "en" {
                XCTAssertNotEqual(localizedBundle.localizedString(forKey: "Antigravity coding quota", value: nil, table: nil), "Antigravity coding quota", "Expected a translated quota title in \(language)")
            }
        }
    }
}
