import XCTest
@testable import MacBookOptimizationApp

final class BatterySnapshotPresentationTests: XCTestCase {
    func testLevelInsightPrefersFullyChargedACSummary() {
        let localizer = AppLocalizer(language: .english)
        let metrics = BatteryMetrics(
            timestamp: Date(),
            level: 100,
            powerSource: .ac,
            chargingState: .charged,
            condition: .normal,
            cycleCount: 34,
            fullChargeCapacity: 4900,
            designCapacity: 5000,
            currentCharge: 4900,
            chargerWattage: 70,
            chargerAdapterName: "70W USB-C Power Adapter",
            temperature: 28.0,
            manufactureDate: nil,
            serialNumber: nil,
            isLowPowerModeEnabled: false
        )

        XCTAssertEqual(
            BatterySnapshotPresentation.levelInsight(metrics: metrics, localizer: localizer),
            "Battery is fully charged and running on AC power"
        )
    }

    func testHealthInsightUsesHealthPercentageWhenAvailable() {
        let localizer = AppLocalizer(language: .english)
        let metrics = BatteryMetrics(
            timestamp: Date(),
            level: 82,
            powerSource: .ac,
            chargingState: .charging,
            condition: .normal,
            cycleCount: 78,
            fullChargeCapacity: 4400,
            designCapacity: 5000,
            currentCharge: 4100,
            chargerWattage: 70,
            chargerAdapterName: "70W USB-C Power Adapter",
            temperature: 29.0,
            manufactureDate: nil,
            serialNumber: nil,
            isLowPowerModeEnabled: false
        )

        XCTAssertEqual(
            BatterySnapshotPresentation.healthInsight(metrics: metrics, localizer: localizer),
            "Battery health is stable at 88.0% of original capacity"
        )
    }

    func testDetailInsightMapsTemperatureStatus() {
        let localizer = AppLocalizer(language: .english)
        let metrics = BatteryMetrics(
            timestamp: Date(),
            level: 60,
            powerSource: .battery,
            chargingState: .discharging,
            condition: .normal,
            cycleCount: 120,
            fullChargeCapacity: 4100,
            designCapacity: 5000,
            currentCharge: 3000,
            chargerWattage: nil,
            chargerAdapterName: nil,
            temperature: 27.5,
            manufactureDate: nil,
            serialNumber: nil,
            isLowPowerModeEnabled: true
        )

        XCTAssertEqual(
            BatterySnapshotPresentation.detailInsight(metrics: metrics, localizer: localizer),
            "Temperature is within normal range"
        )
    }

    func testLastUpdatedTextUsesRelativeSummaryForFreshSamples() {
        let localizer = AppLocalizer(language: .english)
        let now = Date(timeIntervalSince1970: 1_000)
        let updatedAt = now.addingTimeInterval(-2)

        XCTAssertEqual(
            BatterySnapshotPresentation.lastUpdatedText(updatedAt: updatedAt, now: now, localizer: localizer),
            "Updated just now"
        )
    }

    func testChangedFieldsCapturesPrimaryMetricChanges() {
        let previous = BatteryMetrics(
            timestamp: Date(timeIntervalSince1970: 100),
            level: 60,
            powerSource: .battery,
            chargingState: .discharging,
            condition: .normal,
            cycleCount: 100,
            fullChargeCapacity: 4300,
            designCapacity: 5000,
            currentCharge: 3000,
            chargerWattage: nil,
            chargerAdapterName: nil,
            temperature: 29.0,
            manufactureDate: nil,
            serialNumber: nil,
            isLowPowerModeEnabled: false
        )

        let current = BatteryMetrics(
            timestamp: Date(timeIntervalSince1970: 130),
            level: 62,
            powerSource: .ac,
            chargingState: .charging,
            condition: .normal,
            cycleCount: 100,
            fullChargeCapacity: 4300,
            designCapacity: 5000,
            currentCharge: 3200,
            chargerWattage: 70,
            chargerAdapterName: "70W USB-C Power Adapter",
            temperature: 31.5,
            manufactureDate: nil,
            serialNumber: nil,
            isLowPowerModeEnabled: false
        )

        let changed = BatterySnapshotPresentation.changedFields(from: previous, to: current)

        XCTAssertTrue(changed.contains(.level))
        XCTAssertTrue(changed.contains(.powerSource))
        XCTAssertTrue(changed.contains(.chargingState))
        XCTAssertTrue(changed.contains(.charger))
        XCTAssertTrue(changed.contains(.temperature))
        XCTAssertFalse(changed.contains(.health))
    }
}
