import XCTest
@testable import MacBookOptimizationApp

final class SystemInfoViewPresentationTests: XCTestCase {
    func testSystemInfoViewUsesDisplayDescriptorAndStandardStorageFormat() {
        let summary = MachineSummary(
            modelName: "MacBook Pro",
            marketingModel: "MacBook Pro (16-inch)",
            chip: "Apple M2 Pro",
            coreDescription: "12-core CPU",
            gpuDescription: "19-core GPU",
            memoryBytes: 34_359_738_368,
            storageTotalBytes: 494_000_000_000,
            storageAvailableBytes: 167_000_000_000,
            displayName: "Built-in Liquid Retina XDR Display",
            displayResolution: "3456 × 2234 • 120Hz",
            systemVersion: "macOS 15",
            battery: nil
        )
        let localizer = AppLocalizer(language: .english)
        let memoryMetrics = MemoryMetrics(
            timestamp: .now,
            totalBytes: 34_359_738_368,
            appBytes: 12_884_901_888,
            wiredBytes: 4_294_967_296,
            compressedBytes: 2_147_483_648,
            cachedBytes: 10_737_418_240,
            freeBytes: 4_294_967_296,
            swapUsedBytes: 0,
            pageSizeBytes: 16_384
        )
        let view = SystemInfoView(summary: summary, memoryMetrics: memoryMetrics, localizer: localizer)

        XCTAssertEqual(summary.displayName, "Built-in Liquid Retina XDR Display")
        XCTAssertEqual(summary.displayResolution, "3456 × 2234 • 120Hz")
        XCTAssertEqual(view.memoryUsedValueText, MemoryMetrics.format(bytes: memoryMetrics.usedBytes))
        XCTAssertEqual(view.memoryAvailableValueText, MemoryMetrics.format(bytes: memoryMetrics.availableBytes))
    }

    func testSystemInfoViewKeepsBatteryPresentationConcise() {
        let summary = MachineSummary(
            modelName: "MacBook Pro",
            marketingModel: "MacBook Pro (14-inch)",
            chip: "Apple M3 Pro",
            coreDescription: "11-core CPU",
            gpuDescription: "14-core GPU",
            memoryBytes: 18_000_000_000,
            storageTotalBytes: 512_000_000_000,
            storageAvailableBytes: 256_000_000_000,
            displayName: "Built-in Liquid Retina XDR Display",
            displayResolution: "3024 × 1964 • 120Hz",
            systemVersion: "macOS 15",
            battery: BatterySummary(
                chargePercent: "82%",
                condition: "Normal",
                cycleCount: "145",
                powerSource: "Battery Power"
            )
        )
        let localizer = AppLocalizer(language: .english)
        let view = SystemInfoView(summary: summary, memoryMetrics: nil, localizer: localizer)

        XCTAssertEqual(view.batterySemanticLine, "On Battery • Healthy")
    }

    func testSystemInfoViewUsesLocalizedFallbackStrings() {
        let localizer = AppLocalizer(language: .vietnamese)
        let view = SystemInfoView(summary: nil, memoryMetrics: nil, localizer: localizer)

        XCTAssertEqual(view.summaryLine, "Apple Silicon • Không khả dụng • macOS")
    }

    func testSystemInfoViewEmphasizesMemoryCardWhenPressureElevates() {
        let summary = MachineSummary(
            modelName: "MacBook Pro",
            marketingModel: "MacBook Pro (14-inch)",
            chip: "Apple M3 Pro",
            coreDescription: "11-core CPU",
            gpuDescription: "14-core GPU",
            memoryBytes: 18_000_000_000,
            storageTotalBytes: 512_000_000_000,
            storageAvailableBytes: 256_000_000_000,
            displayName: "Built-in Liquid Retina XDR Display",
            displayResolution: "3024 × 1964 • 120Hz",
            systemVersion: "macOS 15",
            battery: nil
        )
        let metrics = MemoryMetrics(
            timestamp: .now,
            totalBytes: 18_000_000_000,
            appBytes: 7_500_000_000,
            wiredBytes: 4_000_000_000,
            compressedBytes: 2_500_000_000,
            cachedBytes: 1_000_000_000,
            freeBytes: 300_000_000,
            swapUsedBytes: 900_000_000,
            pageSizeBytes: 16_384
        )
        let view = SystemInfoView(summary: summary, memoryMetrics: metrics, localizer: AppLocalizer(language: .english))

        XCTAssertEqual(view.memoryEmphasis, .elevated)
        XCTAssertEqual(view.memoryAccentColor, .orange)
        XCTAssertEqual(view.memoryBarSegments.count, 4)
        XCTAssertEqual(view.memoryBarSegments.map(\.bytes).reduce(0, +), metrics.usedBytes + metrics.availableBytes)
    }

    func testSystemInfoViewBuildsBatteryBarFromRealMetrics() {
        let summary = MachineSummary(
            modelName: "MacBook Pro",
            marketingModel: "MacBook Pro (14-inch)",
            chip: "Apple M3 Pro",
            coreDescription: "11-core CPU",
            gpuDescription: "14-core GPU",
            memoryBytes: 18_000_000_000,
            storageTotalBytes: 512_000_000_000,
            storageAvailableBytes: 256_000_000_000,
            displayName: "Built-in Liquid Retina XDR Display",
            displayResolution: "3024 × 1964 • 120Hz",
            systemVersion: "macOS 15",
            battery: BatterySummary(
                chargePercent: "82%",
                condition: "Normal",
                cycleCount: "145",
                powerSource: "AC Power"
            )
        )
        let view = SystemInfoView(summary: summary, memoryMetrics: nil, localizer: AppLocalizer(language: .english))

        XCTAssertEqual(view.batteryFillRatio, 0.82, accuracy: 0.001)
        XCTAssertEqual(view.batterySemanticLine, "AC Power • Healthy")
    }
}
