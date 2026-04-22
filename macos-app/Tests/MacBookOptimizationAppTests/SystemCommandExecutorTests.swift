import XCTest
@testable import MacBookOptimizationApp

final class SystemCommandExecutorTests: XCTestCase {
    func testRegularShellArgumentsSkipUserStartupFiles() {
        XCTAssertEqual(
            SystemCommandExecutor.regularShellArguments(for: "echo ok"),
            ["-f", "-c", "echo ok"]
        )
    }

    func testUserCancelledAdministratorPromptIsDetectedFromAppleScriptOutput() {
        XCTAssertTrue(SystemCommandExecutor.isUserCancelledAdministratorPrompt("execution error: User canceled. (-128)"))
        XCTAssertTrue(SystemCommandExecutor.isUserCancelledAdministratorPrompt("User cancelled."))
        XCTAssertFalse(SystemCommandExecutor.isUserCancelledAdministratorPrompt("authentication error: credentials rejected"))
    }
}
