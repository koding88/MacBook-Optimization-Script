import XCTest
@testable import MacBookOptimizationApp

final class AppLocalizerTests: XCTestCase {
    func testInspectionSummaryRuntimeKeysExistInBothLanguages() {
        let english = AppLocalizer(language: .english)
        let vietnamese = AppLocalizer(language: .vietnamese)

        let requiredKeys: [LocalizedKey] = [
            .snapshotCPUUsage,
            .snapshotCPUCores,
            .snapshotMemoryFree,
            .snapshotMemoryCompressed,
            .snapshotBatteryPowerSource,
            .snapshotBatteryState,
            .snapshotBatteryCondition,
            .snapshotBatteryCycleCount,
            .done,
            .detailSummary,
            .inspectionToastMessage,
            .resultDialogCompletedMessage,
            .resultDialogInspectionMessage,
            .resultDialogFailedMessage,
            .resultDialogAdministratorCancelledMessage,
            .resultDialogDetailsTitle,
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

    func testFormattedLocalizationInterpolatesArgumentsCorrectly() {
        let localizer = AppLocalizer(language: .english)

        XCTAssertEqual(
            localizer.format(.actionCancelledMessage, "Toggle Power Saving Mode"),
            "Toggle Power Saving Mode was cancelled before execution."
        )
    }

    func testSystemReviewPlanUsesLocalizedStepCopy() {
        let english = AppLocalizer(language: .english)
        let vietnamese = AppLocalizer(language: .vietnamese)
        let action = try! XCTUnwrap(OptimizationCatalog.actions().first(where: { $0.id == "system_performance" }))

        let englishPlan = try! XCTUnwrap(SystemActionReviewPlan.build(for: action, localizer: english))
        let vietnamesePlan = try! XCTUnwrap(SystemActionReviewPlan.build(for: action, localizer: vietnamese))

        XCTAssertEqual(englishPlan.steps.first?.title, "Increase socket backlog")
        XCTAssertEqual(vietnamesePlan.steps.first?.title, "Tăng hàng đợi kết nối")
    }

    func testNetworkReviewPlanUsesLocalizedStepCopy() {
        let english = AppLocalizer(language: .english)
        let vietnamese = AppLocalizer(language: .vietnamese)
        let action = try! XCTUnwrap(OptimizationCatalog.actions().first(where: { $0.id == "network_optimization" }))

        let englishPlan = try! XCTUnwrap(SystemActionReviewPlan.build(for: action, localizer: english))
        let vietnamesePlan = try! XCTUnwrap(SystemActionReviewPlan.build(for: action, localizer: vietnamese))

        XCTAssertEqual(englishPlan.steps.first?.title, "Disable delayed ACK")
        XCTAssertEqual(vietnamesePlan.steps.first?.title, "Tắt delayed ACK")
    }
}
