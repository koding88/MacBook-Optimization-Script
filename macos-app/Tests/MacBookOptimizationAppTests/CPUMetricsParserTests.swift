import XCTest
@testable import MacBookOptimizationApp

final class CPUMetricsParserTests: XCTestCase {
    func testOverallCPUUsageReturnsZeroWhenNoCoresExist() {
        let metrics = CPUMetrics(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            cpuName: "Apple M3 Pro",
            totalCores: 0,
            thermalPressure: .nominal,
            clusters: [],
            cores: [],
            power: .init(cpu: 1200, gpu: 300, ane: 40)
        )

        XCTAssertEqual(metrics.overallCPUUsage, 0)
    }

    func testFrequencyDistributionParsesAllBucketsFromClusterResidencyLine() {
        let output = """
        Current pressure level: Nominal
        CPU Power: 1200 mW
        GPU Power: 300 mW
        ANE Power: 40 mW
        E-Cluster Online: 100%
        E-Cluster HW active frequency: 972 MHz
        E-Cluster HW active residency: 49.0% (660 MHz: 12% 744 MHz: 18.5% 972 MHz: 68.5%)
        E-Cluster idle residency: 31%
        E-Cluster down residency: 20%
        CPU 0 frequency: 660 MHz
        CPU 0 active residency: 42%
        CPU 0 idle residency: 38%
        CPU 0 down residency: 20%
        """

        let metrics = CPUMetricsParser.parse(output, cpuName: "Apple M2 Pro")

        XCTAssertEqual(metrics?.clusters.first?.frequencyDistribution, [
            .init(frequency: 660, percentage: 12),
            .init(frequency: 744, percentage: 18.5),
            .init(frequency: 972, percentage: 68.5)
        ])
    }
}
