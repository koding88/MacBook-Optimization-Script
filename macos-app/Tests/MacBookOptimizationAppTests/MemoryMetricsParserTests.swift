import XCTest
@testable import MacBookOptimizationApp

final class MemoryMetricsParserTests: XCTestCase {
    func testParserBuildsStructuredMemoryMetricsFromVmStatAndSwapUsage() {
        let output = """
        Total RAM Bytes: 34359738368
        Swap Usage:
        vm.swapusage: total = 1024.00M  used = 0.00M  free = 1024.00M  (encrypted)

        VM Stat:
        Mach Virtual Memory Statistics: (page size of 16384 bytes)
        Pages free: 16594.
        Pages active: 741849.
        Pages inactive: 708344.
        Pages speculative: 858.
        Pages throttled: 0.
        Pages wired down: 155884.
        Pages purgeable: 1236.
        "Translation faults": 2101684255.
        Pages copy-on-write: 130330653.
        Pages zero filled: 1127303605.
        Pages reactivated: 27794678.
        Pages purged: 7487962.
        File-backed pages: 486967.
        Anonymous pages: 964084.
        Pages stored in compressor: 836535.
        Pages occupied by compressor: 431964.
        Decompressions: 11437394.
        Compressions: 19497473.
        Pageins: 15246329.
        Pageouts: 80312.
        Swapins: 0.
        Swapouts: 0.
        """

        let metrics = MemoryMetricsParser.parse(output)

        XCTAssertEqual(metrics?.totalBytes, 34_359_738_368)
        XCTAssertEqual(metrics?.swapUsedBytes, 0)
        XCTAssertEqual(metrics?.pageSizeBytes, 16_384)
        XCTAssertEqual(metrics?.usedBytes, 25_426_853_888)
        XCTAssertEqual(metrics?.cachedBytes, 8_012_775_424)
        XCTAssertEqual(metrics?.freeBytes, 271_876_096)
        XCTAssertEqual(metrics?.pressureLevel, .normal)
    }

    func testPressureLevelStaysNormalWhenCachedMemoryIsHealthyAndSwapIsZero() {
        let metrics = MemoryMetrics(
            timestamp: .now,
            totalBytes: 34_359_738_368,
            appBytes: 15_795_142_656,
            wiredBytes: 2_553_389_056,
            compressedBytes: 7_077_298_176,
            cachedBytes: 8_012_775_424,
            freeBytes: 271_876_096,
            swapUsedBytes: 0,
            pageSizeBytes: 16_384
        )

        XCTAssertEqual(metrics.pressureLevel, .normal)
    }

    func testPressureLevelBecomesElevatedWhenSwapStartsGrowingAndAvailableMemoryShrinks() {
        let metrics = MemoryMetrics(
            timestamp: .now,
            totalBytes: 17_179_869_184,
            appBytes: 9_663_676_416,
            wiredBytes: 2_791_546_880,
            compressedBytes: 2_147_483_648,
            cachedBytes: 858_993_459,
            freeBytes: 257_698_038,
            swapUsedBytes: 536_870_912,
            pageSizeBytes: 16_384
        )

        XCTAssertEqual(metrics.pressureLevel, .elevated)
    }

    func testPressureLevelBecomesCriticalWhenSwapUsageIsHeavy() {
        let metrics = MemoryMetrics(
            timestamp: .now,
            totalBytes: 17_179_869_184,
            appBytes: 10_737_418_240,
            wiredBytes: 3_006_477_107,
            compressedBytes: 2_362_232_012,
            cachedBytes: 429_496_729,
            freeBytes: 171_798_691,
            swapUsedBytes: 2_684_354_560,
            pageSizeBytes: 16_384
        )

        XCTAssertEqual(metrics.pressureLevel, .critical)
    }
}
