import XCTest
@testable import MacBookOptimizationApp

final class CPUMonitoringServiceTests: XCTestCase {
    func testNativeBasicCPUCollectorBuildsSnapshotFromNativeProviders() throws {
        let collector = NativeBasicCPUCollector(
            machineSummaryProvider: {
                MachineSummary(
                    modelName: "MacBook Pro",
                    marketingModel: "MacBook Pro 14-inch",
                    chip: "Apple M3 Pro",
                    coreDescription: "12-core CPU",
                    gpuDescription: "18-core GPU",
                    memoryBytes: 18_000_000_000,
                    storageTotalBytes: 512_000_000_000,
                    storageAvailableBytes: 256_000_000_000,
                    displayName: "Built-in Display",
                    displayResolution: "3024 × 1964",
                    systemVersion: "macOS 15.0",
                    battery: nil,
                    serialNumber: nil
                )
            },
            processorCountProvider: { 12 },
            overallUsageProvider: { 37.5 },
            thermalStateProvider: { .serious },
            timestampProvider: { Date(timeIntervalSince1970: 1_717_171_717) }
        )

        let metrics = try collector.collectSnapshot()

        XCTAssertEqual(metrics.cpuName, "Apple M3 Pro")
        XCTAssertEqual(metrics.totalCores, 12)
        XCTAssertEqual(metrics.overallUsage, 37.5)
        XCTAssertEqual(metrics.thermalState, .heavy)
        XCTAssertEqual(metrics.timestamp, Date(timeIntervalSince1970: 1_717_171_717))
    }

    func testNativeBasicCPUCollectorPrefersProcessorCountWhenCoreDescriptionMissing() throws {
        let collector = NativeBasicCPUCollector(
            machineSummaryProvider: {
                MachineSummary(
                    modelName: "Mac mini",
                    chipName: "Apple M2",
                    memory: "16 GB",
                    storage: "512 GB",
                    systemVersion: "macOS 15.0",
                    battery: nil,
                    serialNumber: nil
                )
            },
            processorCountProvider: { 8 },
            overallUsageProvider: { 12.25 },
            thermalStateProvider: { .nominal }
        )

        let metrics = try collector.collectSnapshot()

        XCTAssertEqual(metrics.totalCores, 8)
        XCTAssertEqual(metrics.thermalState, .nominal)
    }

    func testMonitoringShellCommandUsesConfiguredIntervalInsteadOfHardcodedOneSecond() {
        let command = AdvancedCPUMonitoringService.monitoringShellCommand(
            outputFilePath: "/tmp/output.log",
            stopFilePath: "/tmp/stop.flag",
            sampleIntervalMilliseconds: 5_000
        )

        XCTAssertTrue(command.contains("-i \"$2\""))
        XCTAssertTrue(command.contains("sh \"$stop_file\" 5000"))
        XCTAssertFalse(command.contains(" -i 1000 "))
        XCTAssertFalse(command.contains("nohup"))
        XCTAssertTrue(command.contains("</dev/null & printf 'started\\n'"))
    }

    func testLastCompleteSampleReturnsMostRecentFinishedBlock() {
        let output = """
        first line
        __MBO_SAMPLE_END__
        second line
        __MBO_SAMPLE_END__
        partial
        """

        let sample = AdvancedCPUMonitoringService.lastCompleteSample(
            in: output,
            delimiter: "\n__MBO_SAMPLE_END__\n"
        )

        XCTAssertEqual(sample, "second line")
    }
}
