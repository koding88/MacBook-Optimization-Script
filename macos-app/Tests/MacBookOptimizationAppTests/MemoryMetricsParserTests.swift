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
        XCTAssertEqual(metrics?.pressureLevel, .elevated)
    }
}
