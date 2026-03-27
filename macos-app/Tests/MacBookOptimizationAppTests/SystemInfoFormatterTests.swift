import XCTest
@testable import MacBookOptimizationApp

final class SystemInfoFormatterTests: XCTestCase {
    func testMemorySummaryUsesConciseGigabyteFormat() {
        let formatter = SystemInfoFormatter(localizer: AppLocalizer(language: .english))

        let value = formatter.memorySummary(memoryBytes: 34_359_738_368)

        XCTAssertEqual(value, "32 GB")
    }

    func testStorageSummaryUsesSingleProjectWideFormat() {
        let formatter = SystemInfoFormatter(localizer: AppLocalizer(language: .english))

        let value = formatter.storageSummary(totalBytes: 494_000_000_000, availableBytes: 167_000_000_000)

        XCTAssertEqual(value, "167.00 GB of 494.00 GB used")
    }

    func testDisplaySummaryPrefersShortDescriptorThenResolution() {
        let formatter = SystemInfoFormatter(localizer: AppLocalizer(language: .english))

        let value = formatter.displaySummary(name: "Liquid Retina XDR", resolution: "3456 × 2234")

        XCTAssertEqual(value.primary, "Liquid Retina XDR")
        XCTAssertEqual(value.secondary, "3456 × 2234")
    }
}
