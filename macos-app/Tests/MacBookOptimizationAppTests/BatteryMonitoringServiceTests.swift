import XCTest
@testable import MacBookOptimizationApp

final class BatteryMonitoringServiceTests: XCTestCase {
    func testFetchCurrentMetricsDelegatesToCollector() async throws {
        let collector = StubBatterySnapshotCollector(metrics: .fixture(level: 73))
        let service = BatteryMonitoringService(collector: collector)

        let metrics = try await service.fetchCurrentMetrics()

        XCTAssertEqual(metrics.level, 73)
    }

    func testStartMonitoringYieldsInitialSnapshot() async throws {
        let collector = StubBatterySnapshotCollector(metrics: .fixture(level: 88))
        let service = BatteryMonitoringService(collector: collector)

        let stream = try await service.startMonitoring(interval: 60)
        let first = await stream.first(where: { _ in true })

        XCTAssertEqual(first?.level, 88)
        service.stopMonitoring()
    }
}

private struct StubBatterySnapshotCollector: BatterySnapshotCollecting {
    let metrics: BatteryMetrics

    func collectSnapshot() throws -> BatteryMetrics {
        metrics
    }
}

private extension BatteryMetrics {
    static func fixture(level: Int = 85) -> BatteryMetrics {
        BatteryMetrics(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            level: level,
            powerSource: .ac,
            chargingState: .charging,
            condition: .normal,
            cycleCount: 120,
            fullChargeCapacity: 7600,
            designCapacity: 8200,
            currentCharge: 7300,
            chargerWattage: 94,
            chargerAdapterName: "96W USB-C Power Adapter",
            temperature: 29.5,
            manufactureDate: Date(timeIntervalSince1970: 1_680_000_000),
            serialNumber: "BATTERY123",
            isLowPowerModeEnabled: false
        )
    }
}
