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
            pidFilePath: "/tmp/powermetrics.pid",
            sampleIntervalMilliseconds: 5_000
        )

        XCTAssertTrue(command.contains("\"$2\""))
        XCTAssertFalse(command.contains(" -i 1000 "))
        XCTAssertFalse(command.contains(" -n 1"))
        XCTAssertFalse(command.contains("nohup"))
        XCTAssertTrue(command.contains("/bin/sh -c"))
        XCTAssertTrue(command.contains("--format plist"))
        XCTAssertTrue(command.contains("pid_file="))
        XCTAssertTrue(command.contains("cat \"$pid_file\""))
        XCTAssertTrue(command.contains("kill -TERM"))
        XCTAssertTrue(command.contains("printf \"%s\" \"$$\" > \"$1\""))
        XCTAssertTrue(command.contains("exec /usr/bin/powermetrics"))
        XCTAssertTrue(command.contains("sh \"$pid_file\" \"$interval_ms\""))
        XCTAssertTrue(command.contains(">/dev/null 2>&1 &"))
    }

    func testProcessExistsCheckTreatsEPermAsAlive() {
        XCTAssertTrue(AdvancedCPUMonitoringService.processExistsCheckSucceeded(result: -1, errnoValue: EPERM))
        XCTAssertTrue(AdvancedCPUMonitoringService.processExistsCheckSucceeded(result: 0, errnoValue: 0))
        XCTAssertFalse(AdvancedCPUMonitoringService.processExistsCheckSucceeded(result: -1, errnoValue: ESRCH))
    }
}
