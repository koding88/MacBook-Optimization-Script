import XCTest
@testable import MacBookOptimizationApp

final class SystemBatteryConditionProviderTests: XCTestCase {
    func testCurrentConditionReadsHealthDictionaryShape() {
        let provider = SystemBatteryConditionProvider()
        let entries: [[String: Any]] = [[
            "_name": "spbattery_information",
            "sppower_battery_health_info": [
                "sppower_battery_health": "Good",
                "sppower_battery_health_maximum_capacity": "88%"
            ]
        ]]

        let condition = provider.currentCondition(from: entries)

        XCTAssertEqual(condition, .normal)
    }
}
