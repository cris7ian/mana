import XCTest
@testable import ManaIOS

final class MobilePresentationTests: XCTestCase {
    func testOldSnapshotIsStaleEvenWithoutAFetchError() {
        let received = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(MobilePresentation.isStale(receivedAt: received, now: received.addingTimeInterval(901)))
        XCTAssertFalse(MobilePresentation.isStale(receivedAt: received, now: received.addingTimeInterval(30)))
    }
}
