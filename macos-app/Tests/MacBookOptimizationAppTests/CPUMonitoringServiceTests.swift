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

    func testGPUMonitoringShellCommandRequestsGpuPowerAndProcessMetrics() {
        let command = GPUMonitoringService.monitoringShellCommand(
            outputFilePath: "/tmp/gpu-output.log",
            stopFilePath: "/tmp/gpu-stop.flag",
            sampleIntervalMilliseconds: 5_000
        )

        XCTAssertTrue(command.contains("--samplers gpu_power,tasks"))
        XCTAssertTrue(command.contains("--show-process-gpu"))
        XCTAssertTrue(command.contains("--format plist"))
        XCTAssertTrue(command.contains("\"$2\""))
        XCTAssertTrue(command.contains("exec /usr/bin/powermetrics"))
    }

    func testGPUMonitoringShellCommandCleansUpStaleWorkerArtifacts() {
        let command = AdvancedGPUMonitoringService.monitoringShellCommand(
            outputFilePath: "/tmp/gpu-output.log",
            stopFilePath: "/tmp/gpu-stop.flag",
            pidFilePath: "/tmp/gpu-powermetrics.pid",
            sampleIntervalMilliseconds: 5_000
        )

        XCTAssertTrue(command.contains("if [ -f \"$pid_file\" ]"))
        XCTAssertTrue(command.contains("cat \"$pid_file\""))
        XCTAssertTrue(command.contains("kill -TERM \"$stale_pid\""))
        XCTAssertTrue(command.contains("kill -KILL \"$stale_pid\""))
        XCTAssertTrue(command.contains("rm -f \"$stop_file\" \"$pid_file\""))
    }

    func testGpuMonitoringConsumesTextFallbackSampleWhenPlistUnavailable() {
        var output = Data("""
        *** Sampled system activity (Sat Apr 25 04:10:57 2026 +0700) (5025.46ms elapsed) ***

        *** Running tasks ***

        Name                               ID     CPU ms/s  User%  Deadlines (<2 ms, 2-5 ms)  Wakeups (Intr, Pkg idle)  GPU ms/s
        WindowServer                       169    171.70    54.31  52.88   0.00               235.18  2.78              0.00
        ALL_TASKS                          -2     1133.80   54.83  7947.74 42.38              10169.82 360.76            0.00

        **** GPU usage ****

        GPU HW active frequency: 444 MHz
        GPU HW active residency:  16.70% (444 MHz:  17% 612 MHz:   0%)
        GPU idle residency:  83.30%
        GPU Power: 61 mW
        """.utf8)

        let samples = AdvancedGPUMonitoringService.consumeCompleteTextSamples(from: &output)

        XCTAssertEqual(samples.count, 1)
        let metrics = GPUMetricsParser.parse(samples[0])
        XCTAssertEqual(metrics?.frequencyMHz, 444)
        XCTAssertEqual(metrics?.powerMilliwatts, 61)
        XCTAssertEqual(metrics?.usagePercent ?? -1, 16.7, accuracy: 0.1)
    }
}
