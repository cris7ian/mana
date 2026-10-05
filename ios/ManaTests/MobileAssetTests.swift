import UIKit
import XCTest
@testable import ManaIOS

final class MobileAssetTests: XCTestCase {
    func testBrandAndProviderImagesAreAvailableOnIPhone() throws {
        for name in ["ManaBrandIcon", "Provider-codex", "Provider-opencode"] {
            let image = try XCTUnwrap(UIImage(named: name), "Missing iPhone asset: \(name)")
            XCTAssertGreaterThan(image.size.width, 0)
        }
    }
}
