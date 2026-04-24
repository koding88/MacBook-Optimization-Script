import XCTest
@testable import MacBookOptimizationApp

final class MemorySnapshotPresentationTests: XCTestCase {
    func testChangedFieldsReturnsPressureUsageAndSwapWhenPressureAndUsageChange() {
        let previous = MemoryMetrics(
            timestamp: Date(timeIntervalSince1970: 10),
            totalBytes: 16_000,
            appBytes: 5_000,
            wiredBytes: 1_000,
            compressedBytes: 500,
            cachedBytes: 6_000,
            freeBytes: 3_500,
            swapUsedBytes: 0,
            pageSizeBytes: 4_096
        )
        let current = MemoryMetrics(
            timestamp: Date(timeIntervalSince1970: 20),
            totalBytes: 16_000,
            appBytes: 7_000,
            wiredBytes: 2_000,
            compressedBytes: 1_000,
            cachedBytes: 4_000,
            freeBytes: 2_000,
            swapUsedBytes: 600,
            pageSizeBytes: 4_096
        )

        let changed = MemorySnapshotPresentation.changedFields(from: previous, to: current)

        XCTAssertEqual(changed, [.pressure, .usage, .swap])
    }

    func testChangedFieldsDetectsInitialSnapshotAsAnimatedGroups() {
        let current = MemoryMetrics(
            timestamp: Date(timeIntervalSince1970: 20),
            totalBytes: 16_000,
            appBytes: 4_000,
            wiredBytes: 1_000,
            compressedBytes: 500,
            cachedBytes: 6_000,
            freeBytes: 4_500,
            swapUsedBytes: 0,
            pageSizeBytes: 4_096
        )

        let changed = MemorySnapshotPresentation.changedFields(from: nil, to: current)

        XCTAssertEqual(changed, [.pressure, .usage, .swap])
    }

    func testHeaderPaletteReturnsLivePaletteForNormalPressure() {
        let metrics = MemoryMetrics(
            timestamp: Date(timeIntervalSince1970: 20),
            totalBytes: 16_000,
            appBytes: 4_000,
            wiredBytes: 1_000,
            compressedBytes: 500,
            cachedBytes: 6_000,
            freeBytes: 4_500,
            swapUsedBytes: 0,
            pageSizeBytes: 4_096
        )

        let palette = MemorySnapshotPresentation.headerPalette(for: metrics)

        XCTAssertEqual(palette.iconSymbol, "memorychip.fill")
        XCTAssertEqual(palette.statusSymbol, "waveform.path.ecg")
        XCTAssertEqual(palette.emphasis, .normal)
    }

    func testHeaderPaletteReturnsCriticalPaletteForCriticalPressure() {
        let metrics = MemoryMetrics(
            timestamp: Date(timeIntervalSince1970: 20),
            totalBytes: 16_000,
            appBytes: 9_000,
            wiredBytes: 3_000,
            compressedBytes: 2_000,
            cachedBytes: 500,
            freeBytes: 300,
            swapUsedBytes: 3_000,
            pageSizeBytes: 4_096
        )

        let palette = MemorySnapshotPresentation.headerPalette(for: metrics)

        XCTAssertEqual(palette.statusSymbol, "flame.fill")
        XCTAssertEqual(palette.emphasis, .critical)
    }

    func testUsageBreakdownItemsReturnExpectedAccentOrder() {
        let metrics = MemoryMetrics(
            timestamp: Date(timeIntervalSince1970: 20),
            totalBytes: 16_000,
            appBytes: 5_000,
            wiredBytes: 2_000,
            compressedBytes: 1_000,
            cachedBytes: 4_000,
            freeBytes: 4_000,
            swapUsedBytes: 500,
            pageSizeBytes: 4_096
        )

        let items = MemorySnapshotPresentation.usageBreakdownItems(for: metrics)

        XCTAssertEqual(items.map(\.titleKey), [
            .memorySnapshotAppMemory,
            .memorySnapshotWiredMemory,
            .memorySnapshotCompressed,
            .memorySnapshotCachedFiles,
            .memorySnapshotFreeMemory
        ])
        XCTAssertEqual(items.map(\.iconSymbol), [
            "app.badge.fill",
            "cpu.fill",
            "square.stack.3d.down.right.fill",
            "externaldrive.fill",
            "circlebadge"
        ])
    }

    func testUsageBreakdownBarAvailableWidthSubtractsSpacingAndPadding() {
        let availableWidth = MemorySnapshotPresentation.usageBreakdownBarAvailableWidth(
            totalWidth: 300,
            itemCount: 5,
            spacing: 3,
            horizontalPadding: 4
        )

        XCTAssertEqual(availableWidth, 280, accuracy: 0.001)
    }

    func testUsageBreakdownSegmentWidthsFillAvailableWidthExactly() {
        let widths = MemorySnapshotPresentation.usageBreakdownSegmentWidths(
            values: [5_000, 2_000, 1_000, 4_000, 4_000],
            totalWidth: 300,
            spacing: 3,
            horizontalPadding: 4
        )

        XCTAssertEqual(widths.count, 5)
        XCTAssertEqual(widths.reduce(0, +), 280, accuracy: 0.001)
    }
}
