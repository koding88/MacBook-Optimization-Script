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
        let view = SystemInfoView(summary: summary, localizer: localizer)

        XCTAssertEqual(summary.displayName, "Built-in Liquid Retina XDR Display")
        XCTAssertEqual(summary.displayResolution, "3456 × 2234 • 120Hz")
        XCTAssertEqual(
            view.detailRows,
            [
                SystemInfoView.DetailRow(label: "Chip", value: "Apple M2 Pro", secondaryValue: "12-core CPU • 19-core GPU"),
                SystemInfoView.DetailRow(label: "Memory", value: "32 GB", secondaryValue: nil),
                SystemInfoView.DetailRow(label: "Storage", value: "167.00 GB of 494.00 GB used", secondaryValue: nil),
                SystemInfoView.DetailRow(label: "Display", value: "Built-in Liquid Retina XDR Display", secondaryValue: "3456 × 2234 • 120Hz")
            ]
        )
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
        let view = SystemInfoView(summary: summary, localizer: localizer)

        XCTAssertTrue(view.detailRows.contains { $0.label == "Battery" && $0.value == "82%" })
        XCTAssertFalse(view.detailRows.contains { $0.label == "Cycle Count" })
        XCTAssertFalse(view.detailRows.contains { $0.label == "Health" })
    }
}
