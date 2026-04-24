import XCTest
@testable import MacBookOptimizationApp

final class MemoryMonitoringServiceTests: XCTestCase {
    func testSnapshotCommandKeepsShellFallbackForSwapUsage() {
        let command = MemorySnapshotCommand.combinedCommand

        XCTAssertTrue(command.contains("Total RAM Bytes"))
        XCTAssertTrue(command.contains("sysctl vm.swapusage"))
        XCTAssertTrue(command.contains("vm_stat"))
    }

    func testNativeMemorySnapshotCollectorBuildsMetricsFromNativeStatsAndSwapUsage() throws {
        let collector = NativeMemorySnapshotCollector(
            totalMemoryProvider: { 34_359_738_368 },
            vmStatisticsProvider: {
                MemoryVMStatistics(
                    freePages: 16_594,
                    speculativePages: 858,
                    wiredPages: 155_884,
                    purgeablePages: 1_236,
                    fileBackedPages: 486_967,
                    anonymousPages: 964_084,
                    compressedPages: 431_964,
                    pageSizeBytes: 16_384
                )
            },
            swapUsageProvider: { 268_435_456 }
        )

        let metrics = try collector.collectSnapshot()

        XCTAssertEqual(metrics.totalBytes, 34_359_738_368)
        XCTAssertEqual(metrics.swapUsedBytes, 268_435_456)
        XCTAssertEqual(metrics.pageSizeBytes, 16_384)
        XCTAssertEqual(metrics.usedBytes, 25_426_853_888)
        XCTAssertEqual(metrics.cachedBytes, 8_012_775_424)
        XCTAssertEqual(metrics.freeBytes, 271_876_096)
        XCTAssertEqual(metrics.pressureLevel, MemoryMetrics.PressureLevel.normal)
    }

    func testNativeMemorySnapshotCollectorDefaultsSwapToZeroWhenUnavailable() throws {
        let collector = NativeMemorySnapshotCollector(
            totalMemoryProvider: { 8_589_934_592 },
            vmStatisticsProvider: {
                MemoryVMStatistics(
                    freePages: 1_024,
                    speculativePages: 512,
                    wiredPages: 2_048,
                    purgeablePages: 256,
                    fileBackedPages: 4_096,
                    anonymousPages: 8_192,
                    compressedPages: 1_024,
                    pageSizeBytes: 16_384
                )
            },
            swapUsageProvider: { nil }
        )

        let metrics = try collector.collectSnapshot()

        XCTAssertEqual(metrics.swapUsedBytes, 0)
    }

    func testNativeSwapUsageReaderReturnsUsedBytesFromKernelStructure() throws {
        let usedBytes = try NativeMemorySnapshotCollector.parseSwapUsage(
            MemorySwapUsage(totalBytes: 1_073_741_824, availableBytes: 805_306_368, usedBytes: 268_435_456, pageSizeBytes: 4_096, isEncrypted: true)
        )

        XCTAssertEqual(usedBytes, 268_435_456)
    }
}
