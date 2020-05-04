import XCTest
@testable import MPConnectivity

final class MPConnectivityTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(MPConnectivity().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
