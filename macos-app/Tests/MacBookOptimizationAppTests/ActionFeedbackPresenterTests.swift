import XCTest
@testable import MacBookOptimizationApp

final class ActionFeedbackPresenterTests: XCTestCase {
    func testCpuSnapshotUsesConciseStructuredToastAndActivityCopy() {
        let presenter = ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        let action = OptimizationAction(
            id: "system_check_cpu",
            titleKey: "action.system_check_cpu.title",
            descriptionKey: "action.system_check_cpu.description",
            category: .system,
            symbolName: "cpu",
            statusFeatureID: nil,
            isRisky: false,
            estimatedTime: "Instant",
            requiresRestart: false,
            kind: .manual(""),
            status: .ready
        )

        let result = presenter.presentInspection(
            action: action,
            title: "CPU Snapshot",
            summaryLines: ["CPU: Apple M2 Pro", "Cores: 12", "Usage: 11%"]
        )

        XCTAssertEqual(result.toast.summaryLines.count, 3)
        XCTAssertTrue(result.activityEvent.message.contains("Apple M2 Pro"))
        XCTAssertNotEqual(result.toast.message, result.activityEvent.message)
    }
}
