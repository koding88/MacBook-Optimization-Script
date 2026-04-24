import XCTest
@testable import MacBookOptimizationApp

final class CPUMetricsParserTests: XCTestCase {
    private let samplePlistData = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>processor</key>
        <dict>
            <key>cpu_power</key>
            <real>3811.02</real>
            <key>gpu_power</key>
            <real>64.5056</real>
            <key>ane_power</key>
            <real>0</real>
            <key>clusters</key>
            <array>
                <dict>
                    <key>name</key>
                    <string>E-Cluster</string>
                    <key>freq_hz</key>
                    <real>1296410000</real>
                    <key>online_ratio</key>
                    <real>1.0</real>
                    <key>idle_ratio</key>
                    <real>0.327863</real>
                    <key>down_ratio</key>
                    <real>0.0</real>
                    <key>dvfm_states</key>
                    <array>
                        <dict>
                            <key>freq</key>
                            <integer>912</integer>
                            <key>used_ratio</key>
                            <real>0.444261</real>
                        </dict>
                        <dict>
                            <key>freq</key>
                            <integer>1284</integer>
                            <key>used_ratio</key>
                            <real>0.0419188</real>
                        </dict>
                    </array>
                    <key>cpus</key>
                    <array>
                        <dict>
                            <key>cpu</key>
                            <integer>0</integer>
                            <key>freq_hz</key>
                            <real>1419910000</real>
                            <key>idle_ratio</key>
                            <real>0.715993</real>
                            <key>down_ratio</key>
                            <real>0.0</real>
                        </dict>
                    </array>
                </dict>
            </array>
        </dict>
        <key>thermal_pressure</key>
        <string>Nominal</string>
    </dict>
    </plist>
    """.data(using: .utf8)!

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

    func testParsePlistBuildsMetricsFromMachineReadableSample() {
        let metrics = CPUMetricsParser.parse(plistData: samplePlistData, cpuName: "Apple M4")

        XCTAssertEqual(metrics?.thermalPressure, .nominal)
        XCTAssertEqual(metrics?.power.cpu, 3811)
        XCTAssertEqual(metrics?.power.gpu, 65)
        XCTAssertEqual(metrics?.power.ane, 0)
        XCTAssertEqual(metrics?.clusters.first?.name, "E-Cluster")
        XCTAssertEqual(metrics?.clusters.first?.frequencyDistribution.count, 2)
        XCTAssertEqual(metrics?.clusters.first?.frequencyDistribution.first?.frequency, 912)
        XCTAssertEqual(metrics?.clusters.first?.frequencyDistribution.first?.percentage ?? 0, 44.4261, accuracy: 0.0001)
        XCTAssertEqual(metrics?.clusters.first?.frequencyDistribution.last?.frequency, 1284)
        XCTAssertEqual(metrics?.clusters.first?.frequencyDistribution.last?.percentage ?? 0, 4.19188, accuracy: 0.0001)
        XCTAssertEqual(metrics?.cores.first?.id, 0)
        XCTAssertEqual(metrics?.cores.first?.frequency, 1420)
    }
}
