import XCTest
@testable import MacBookOptimizationApp

final class SystemCommandExecutorTests: XCTestCase {
    func testRegularShellExecutableUsesBinSh() {
        XCTAssertEqual(SystemCommandExecutor.regularShellExecutablePath, "/bin/sh")
    }

    func testAdministratorShellExecutableUsesBinSh() {
        XCTAssertEqual(SystemCommandExecutor.administratorShellExecutablePath, "/bin/sh")
    }

    func testRegularShellArgumentsSkipUserStartupFiles() {
        XCTAssertEqual(
            SystemCommandExecutor.regularShellArguments(for: "echo ok"),
            ["-c", "echo ok"]
        )
    }

    func testUserCancelledAdministratorPromptIsDetectedFromAppleScriptOutput() {
        XCTAssertTrue(SystemCommandExecutor.isUserCancelledAdministratorPrompt("execution error: User canceled. (-128)"))
        XCTAssertTrue(SystemCommandExecutor.isUserCancelledAdministratorPrompt("User cancelled."))
        XCTAssertFalse(SystemCommandExecutor.isUserCancelledAdministratorPrompt("authentication error: credentials rejected"))
    }
}
