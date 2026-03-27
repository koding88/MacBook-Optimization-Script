import XCTest
@testable import MacBookOptimizationApp

final class SystemInfoViewPresentationTests: XCTestCase {
    func testSystemInfoViewUsesDisplayDescriptorAndStandardStorageFormat() {
        let summary = MachineSummary(
            modelName: "MacBook Pro",
            marketingModel: "MacBook Pro (16-inch)",
            chip: "Apple M2 Pro",
            coreDescription: "12-core CPU",
            memoryBytes: 34_000_000_000,
            storageTotalBytes: 494_000_000_000,
            storageAvailableBytes: 167_000_000_000,
            displayName: "Liquid Retina XDR",
            displayResolution: "3456 × 2234",
            systemVersion: "macOS 15",
            battery: nil
        )
        let localizer = AppLocalizer(language: .english)
        let view = SystemInfoView(summary: summary, localizer: localizer)

        XCTAssertEqual(summary.displayName, "Liquid Retina XDR")
        XCTAssertEqual(summary.displayResolution, "3456 × 2234")
        XCTAssertEqual(
            view.detailRows,
            [
                SystemInfoView.DetailRow(label: "Chip", value: "Apple M2 Pro", secondaryValue: nil),
                SystemInfoView.DetailRow(label: "CPU", value: "12-core CPU", secondaryValue: nil),
                SystemInfoView.DetailRow(label: "Memory", value: "34 GB", secondaryValue: nil),
                SystemInfoView.DetailRow(label: "Storage", value: "494 GB • 167 GB available", secondaryValue: nil),
                SystemInfoView.DetailRow(label: "Display", value: "Liquid Retina XDR", secondaryValue: "3456 × 2234")
            ]
        )
    }

    func testSystemInfoViewKeepsBatteryPresentationConcise() {
        let summary = MachineSummary(
            modelName: "MacBook Pro",
            marketingModel: "MacBook Pro (14-inch)",
            chip: "Apple M3 Pro",
            coreDescription: "11-core CPU",
            memoryBytes: 18_000_000_000,
            storageTotalBytes: 512_000_000_000,
            storageAvailableBytes: 256_000_000_000,
            displayName: "Liquid Retina XDR",
            displayResolution: "3024 × 1964",
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
