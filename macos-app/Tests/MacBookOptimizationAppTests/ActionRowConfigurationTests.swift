import XCTest
@testable import MacBookOptimizationApp

final class ActionRowConfigurationTests: XCTestCase {
    func testRunningStateUsesStableControlWidth() {
        let metrics = ActionRowMetrics.default
        XCTAssertEqual(metrics.buttonWidth, 72)
        XCTAssertEqual(metrics.minimumRowHeight, 86)
    }
}
