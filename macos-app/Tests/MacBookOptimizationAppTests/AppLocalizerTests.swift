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
            .memorySnapshotTitle,
            .memorySnapshotCollecting,
            .memorySnapshotPressure,
            .memorySnapshotPhysicalMemory,
            .memorySnapshotMemoryUsed,
            .memorySnapshotCachedFiles,
            .memorySnapshotSwapUsed,
            .memorySnapshotAppMemory,
            .memorySnapshotWiredMemory,
            .memorySnapshotCompressed,
            .memorySnapshotFreeMemory,
            .snapshotGPUMetal,
            .snapshotDiskAvailable,
            .snapshotDiskMountPoint,
            .snapshotNetworkGateway,
            .snapshotNetworkHardwarePort,
            .snapshotBatteryPowerSource,
            .snapshotBatteryState,
            .snapshotBatteryCondition,
            .snapshotBatteryCycleCount,
            .statusReset,
            .statusResetMessage,
            .statusResetFailedMessage,
            .statusEmpty,
            .done,
            .detailSummary,
            .inspectionToastMessage,
            .resultDialogCompletedMessage,
            .resultDialogInspectionMessage,
            .resultDialogFailedMessage,
            .resultDialogAdministratorCancelledMessage,
            .resultDialogIntelOnlyMessage,
            .resultDialogDetailsTitle,
            .noLogsYet,
            .noOutputYet,
            .storageAvailableSuffix,
            .refreshMinutesFormat,
            .intelOnly,
            .intelOnlyHint,
            .actionUnavailableTitle,
            .actionUnavailableIntelOnlyMessage
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

    func testMemoryReviewPlanUsesLocalizedStepCopy() {
        let english = AppLocalizer(language: .english)
        let vietnamese = AppLocalizer(language: .vietnamese)
        let action = OptimizationAction(
            id: "system_check_memory",
            titleKey: "action.system_check_memory.title",
            descriptionKey: "action.system_check_memory.description",
            category: .monitoring,
            symbolName: "memorychip",
            statusFeatureID: nil,
            isRisky: false,
            estimatedTime: "5-10 seconds",
            requiresRestart: false,
            restoreBehavior: .notRestorableInspection(reasonKey: "restore.reason.inspection"),
            kind: .command(MemorySnapshotCommand.requests),
            status: .ready,
            lastRunDescription: nil
        )

        let englishPlan = try! XCTUnwrap(SystemActionReviewPlan.build(for: action, localizer: english))
        let vietnamesePlan = try! XCTUnwrap(SystemActionReviewPlan.build(for: action, localizer: vietnamese))

        XCTAssertEqual(englishPlan.steps[1].title, "Read swap usage")
        XCTAssertEqual(vietnamesePlan.steps[1].title, "Đọc mức dùng swap")
    }
}
