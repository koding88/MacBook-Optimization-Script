import XCTest
@testable import MacBookOptimizationApp

final class AppLocalizerTests: XCTestCase {
    func testInspectionSummaryRuntimeKeysExistInBothLanguages() {
        let english = AppLocalizer(language: .english)
        let vietnamese = AppLocalizer(language: .vietnamese)

        let requiredKeys: [LocalizedKey] = [
            .snapshotCPUUsage,
            .snapshotCPUCores,
            .done,
            .detailSummary,
            .inspectionToastMessage,
            .noLogsYet,
            .noOutputYet,
            .storageAvailableSuffix,
            .refreshMinutesFormat
        ]

        for key in requiredKeys {
            XCTAssertNotEqual(english.text(key), key.rawValue, "Missing English localization for \(key.rawValue)")
            XCTAssertNotEqual(vietnamese.text(key), key.rawValue, "Missing Vietnamese localization for \(key.rawValue)")
        }
    }

    func testEnglishLocalizationReturnsExpectedString() {
        let localizer = AppLocalizer(language: .english)

        XCTAssertEqual(localizer.text(.appTitle), "MacBook Optimization")
        XCTAssertEqual(localizer.string("action.dns_flush.title"), "Flush DNS Cache")
    }

    func testVietnameseLocalizationReturnsExpectedString() {
        let localizer = AppLocalizer(language: .vietnamese)

        XCTAssertEqual(localizer.text(.categories), "Danh mục")
        XCTAssertEqual(localizer.string("action.dns_flush.title"), "Xóa DNS cache")
    }

    func testMissingLocalizationFallsBackToKey() {
        let localizer = AppLocalizer(language: .english)

        XCTAssertEqual(localizer.string("missing.localization.key"), "missing.localization.key")
    }
}
