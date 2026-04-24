import XCTest
@testable import MacBookOptimizationApp

final class BatterySnapshotChargerInfoContentTests: XCTestCase {
    func testUsesUnavailableFallbackWhenChargerMetricsMissing() {
        let metrics = BatteryMetrics(
            timestamp: Date(),
            level: 63,
            powerSource: .battery,
            chargingState: .discharging,
            condition: .normal,
            cycleCount: 120,
            fullChargeCapacity: 4700,
            designCapacity: 5000,
            currentCharge: 3150,
            chargerWattage: nil,
            chargerAdapterName: nil,
            temperature: 29.5,
            manufactureDate: nil,
            serialNumber: nil,
            isLowPowerModeEnabled: false
        )

        let content = BatterySnapshotChargerInfoContent(
            metrics: metrics,
            unavailableText: "Unavailable"
        )

        XCTAssertEqual(content.wattageText, "Unavailable")
        XCTAssertEqual(content.adapterNameText, "Unavailable")
    }
}
