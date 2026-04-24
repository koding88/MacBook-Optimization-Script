import XCTest
@testable import MacBookOptimizationApp

final class NativeBatteryConditionResolverTests: XCTestCase {
    func testResolvesGoodHealthAsNormal() {
        let resolver = NativeBatteryConditionResolver()

        let condition = resolver.resolve(
            iopsCondition: nil,
            iopsHealth: "Good",
            cycleCount: 180,
            designCycleCount: 1000,
            fullChargeCapacity: 7669,
            designCapacity: 8694,
            batteryHealthMetric: 0
        )

        XCTAssertEqual(condition, .normal)
    }

    func testDowngradesCheckBatteryWhenNativeSignalsRemainHealthy() {
        let resolver = NativeBatteryConditionResolver()

        let condition = resolver.resolve(
            iopsCondition: nil,
            iopsHealth: "Check Battery",
            cycleCount: 180,
            designCycleCount: 1000,
            fullChargeCapacity: 7669,
            designCapacity: 8694,
            batteryHealthMetric: 0
        )

        XCTAssertEqual(condition, .normal)
    }

    func testPreservesExplicitServiceCondition() {
        let resolver = NativeBatteryConditionResolver()

        let condition = resolver.resolve(
            iopsCondition: "Service Battery",
            iopsHealth: nil,
            cycleCount: 940,
            designCycleCount: 1000,
            fullChargeCapacity: 5100,
            designCapacity: 8694,
            batteryHealthMetric: 0
        )

        XCTAssertEqual(condition, .serviceBattery)
    }

    func testEscalatesCheckBatteryWhenCapacityAndCycleCountArePoor() {
        let resolver = NativeBatteryConditionResolver()

        let condition = resolver.resolve(
            iopsCondition: nil,
            iopsHealth: "Check Battery",
            cycleCount: 980,
            designCycleCount: 1000,
            fullChargeCapacity: 5000,
            designCapacity: 8694,
            batteryHealthMetric: 0
        )

        XCTAssertEqual(condition, .serviceBattery)
    }
}
