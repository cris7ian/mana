import XCTest
@testable import ManaIOS

final class AppInformationTests: XCTestCase {
    func testPublicLinksUseExactHTTPSPages() {
        XCTAssertEqual(AppInformation.supportURL.absoluteString, "https://mana.salsaparapizza.com/support.html")
        XCTAssertEqual(AppInformation.privacyURL.absoluteString, "https://mana.salsaparapizza.com/privacy.html")
    }

    func testAppBundleIncludesAppGroupDefaultsReason() throws {
        let url = try XCTUnwrap(Bundle(for: MobileAppModel.self).url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        try verifyManifest(at: url)
    }

    func testEmbeddedWidgetIncludesAppGroupDefaultsReason() throws {
        let app = Bundle(for: MobileAppModel.self).bundleURL
        let url = app.appendingPathComponent("PlugIns/ManaWidgets.appex/PrivacyInfo.xcprivacy")
        try verifyManifest(at: url)
    }

    private func verifyManifest(at url: URL) throws {
        let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let APIs = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(APIs.count, 1)
        XCTAssertEqual(APIs.first?["NSPrivacyAccessedAPIType"] as? String, "NSPrivacyAccessedAPICategoryUserDefaults")
        XCTAssertEqual(APIs.first?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["1C8F.1"])
    }
}
