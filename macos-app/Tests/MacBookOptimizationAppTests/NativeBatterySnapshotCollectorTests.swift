import XCTest
@testable import MacBookOptimizationApp

final class NativeBatterySnapshotCollectorTests: XCTestCase {
    func testCollectorBuildsMetricsFromNativeReaders() throws {
        let powerSourceReader = StubPowerSourceReader(
            description: [
                IOPSPowerSourceSnapshotReader.currentCapacityKey: 100,
                IOPSPowerSourceSnapshotReader.powerSourceStateKey: IOPSPowerSourceSnapshotReader.acPowerValue,
                IOPSPowerSourceSnapshotReader.isChargingKey: false,
                IOPSPowerSourceSnapshotReader.isChargedKey: true,
                IOPSPowerSourceSnapshotReader.batteryHealthKey: "Good",
                IOPSPowerSourceSnapshotReader.hardwareSerialNumberKey: "BAT123"
            ],
            adapterDetails: [
                IOPSPowerSourceSnapshotReader.adapterWattsKey: 94
            ]
        )
        let registryReader = StubRegistryReader(
            rawProperties: [
                AppleSmartBatteryRegistryReader.cycleCountKey: 180,
                AppleSmartBatteryRegistryReader.nominalChargeCapacityKey: 7669,
                AppleSmartBatteryRegistryReader.designCapacityKey: 8694,
                AppleSmartBatteryRegistryReader.appleRawCurrentCapacityKey: 7425,
                AppleSmartBatteryRegistryReader.temperatureKey: 3018,
                AppleSmartBatteryRegistryReader.manufactureDateKey: 19666,
                AppleSmartBatteryRegistryReader.serialKey: "BAT123",
                AppleSmartBatteryRegistryReader.adapterDetailsKey: [
                    AppleSmartBatteryRegistryReader.adapterNameKey: "96W USB-C Power Adapter"
                ]
            ]
        )

        let collector = NativeBatterySnapshotCollector(
            powerSourceReader: powerSourceReader,
            registryReader: registryReader,
            lowPowerModeProvider: { true }
        )

        let metrics = try collector.collectSnapshot()

        XCTAssertEqual(metrics.level, 100)
        XCTAssertEqual(metrics.powerSource, BatteryMetrics.PowerSource.ac)
        XCTAssertEqual(metrics.chargingState, BatteryMetrics.ChargingState.charged)
        XCTAssertEqual(metrics.condition, BatteryMetrics.BatteryCondition.normal)
        XCTAssertEqual(metrics.cycleCount, 180)
        XCTAssertEqual(metrics.fullChargeCapacity, 7669)
        XCTAssertEqual(metrics.designCapacity, 8694)
        XCTAssertEqual(metrics.currentCharge, 7425)
        XCTAssertEqual(metrics.chargerWattage, 94)
        XCTAssertEqual(metrics.chargerAdapterName, "96W USB-C Power Adapter")
        XCTAssertEqual(metrics.serialNumber, "BAT123")
        XCTAssertEqual(metrics.isLowPowerModeEnabled, true)
        XCTAssertNotNil(metrics.manufactureDate)
        XCTAssertEqual(metrics.temperature.map { round($0 * 10) / 10 }, 28.7)
    }

    func testCollectorMapsBatteryPowerToDischarging() throws {
        let collector = NativeBatterySnapshotCollector(
            powerSourceReader: StubPowerSourceReader(
                description: [
                    IOPSPowerSourceSnapshotReader.currentCapacityKey: 42,
                    IOPSPowerSourceSnapshotReader.powerSourceStateKey: IOPSPowerSourceSnapshotReader.batteryPowerValue,
                    IOPSPowerSourceSnapshotReader.isChargingKey: false,
                    IOPSPowerSourceSnapshotReader.isChargedKey: false,
                    IOPSPowerSourceSnapshotReader.batteryHealthConditionKey: "Service Battery"
                ],
                adapterDetails: [:]
            ),
            registryReader: StubRegistryReader(rawProperties: [
                AppleSmartBatteryRegistryReader.cycleCountKey: 980,
                AppleSmartBatteryRegistryReader.designCycleCountKey: 1000,
                AppleSmartBatteryRegistryReader.nominalChargeCapacityKey: 5000,
                AppleSmartBatteryRegistryReader.designCapacityKey: 8694,
                AppleSmartBatteryRegistryReader.batteryDataKey: [
                    AppleSmartBatteryRegistryReader.batteryHealthMetricKey: 0
                ]
            ]),
            lowPowerModeProvider: { false }
        )

        let metrics = try collector.collectSnapshot()

        XCTAssertEqual(metrics.powerSource, BatteryMetrics.PowerSource.battery)
        XCTAssertEqual(metrics.chargingState, BatteryMetrics.ChargingState.discharging)
        XCTAssertEqual(metrics.condition, BatteryMetrics.BatteryCondition.serviceBattery)
    }

    func testCollectorUsesSystemConditionOnlyWhenNativeResolverIsUnknown() throws {
        let collector = NativeBatterySnapshotCollector(
            powerSourceReader: StubPowerSourceReader(
                description: [
                    IOPSPowerSourceSnapshotReader.currentCapacityKey: 88,
                    IOPSPowerSourceSnapshotReader.powerSourceStateKey: IOPSPowerSourceSnapshotReader.acPowerValue,
                    IOPSPowerSourceSnapshotReader.isChargingKey: false,
                    IOPSPowerSourceSnapshotReader.isChargedKey: true
                ],
                adapterDetails: [:]
            ),
            registryReader: StubRegistryReader(rawProperties: [:]),
            systemConditionProvider: {
                BatteryMetrics.BatteryCondition.normal
            },
            lowPowerModeProvider: { false }
        )

        let metrics = try collector.collectSnapshot()

        XCTAssertEqual(metrics.condition, .normal)
    }

    func testRegistryReaderFallsBackToBatterySerialForModernManufactureDate() {
        let reader = AppleSmartBatteryRegistryReader()
        let properties: [String: Any] = [
            "BatteryData": [
                AppleSmartBatteryRegistryReader.manufactureDateKey: NSNumber(value: Int64(0x343235303133)),
                AppleSmartBatteryRegistryReader.serialKey: "F5D320650A80VC5BN"
            ],
            AppleSmartBatteryRegistryReader.serialKey: "F5D320650A80VC5BN"
        ]

        let manufactureDate = reader.manufactureDate(from: properties)
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: manufactureDate ?? .distantPast)

        XCTAssertEqual(components.year, 2023)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 19)
    }
}

private struct StubPowerSourceReader: PowerSourceSnapshotReading {
    let description: [String: Any]
    let adapterDetails: [String: Any]

    func internalBatteryDescription() throws -> [String : Any] { description }
    func externalPowerAdapterDetails() -> [String : Any] { adapterDetails }

    func intValue(for key: String, in dictionary: [String : Any]) -> Int? {
        if let number = dictionary[key] as? NSNumber { return number.intValue }
        return dictionary[key] as? Int
    }

    func boolValue(for key: String, in dictionary: [String : Any]) -> Bool? {
        if let value = dictionary[key] as? Bool { return value }
        if let number = dictionary[key] as? NSNumber { return number.boolValue }
        return nil
    }

    func stringValue(for key: String, in dictionary: [String : Any]) -> String? {
        dictionary[key] as? String
    }
}

private struct StubRegistryReader: AppleSmartBatteryRegistryReading {
    let rawProperties: [String: Any]

    func properties() throws -> [String : Any] { rawProperties }
    func adapterDetails(from properties: [String : Any]) -> [String : Any] {
        properties[AppleSmartBatteryRegistryReader.adapterDetailsKey] as? [String: Any] ?? [:]
    }

    func intValue(for key: String, in dictionary: [String : Any]) -> Int? {
        if let number = dictionary[key] as? NSNumber { return number.intValue }
        return dictionary[key] as? Int
    }

    func stringValue(for key: String, in dictionary: [String : Any]) -> String? {
        dictionary[key] as? String
    }

    func temperature(from properties: [String : Any]) -> Double? {
        guard let raw = intValue(for: AppleSmartBatteryRegistryReader.temperatureKey, in: properties) else { return nil }
        return (Double(raw) / 10.0) - 273.15
    }

    func manufactureDate(from properties: [String : Any]) -> Date? {
        guard let raw = intValue(for: AppleSmartBatteryRegistryReader.manufactureDateKey, in: properties) else { return nil }
        let day = raw & 0x1F
        let month = (raw >> 5) & 0x0F
        let year = ((raw >> 9) & 0x7F) + 1980
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
    }

    func batteryData(from properties: [String : Any]) -> [String : Any] {
        properties[AppleSmartBatteryRegistryReader.batteryDataKey] as? [String: Any] ?? [:]
    }
}
