import XCTest
@testable import MacBookOptimizationApp

final class OptimizationEngineTests: XCTestCase {
    func testMutationActionReturnsStructuredFeedbackAndSeparateDebugLog() async throws {
        let executor = MockSystemCommandExecutor(output: "raw shell transcript", exitCode: 0)
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )

        let action = OptimizationCatalog.actions().first(where: { $0.id == "dns_flush" })!
        let result = try await engine.execute(action)

        XCTAssertEqual(result.status, .enabled)
        XCTAssertEqual(result.debugLog?.contains("raw shell transcript"), true)
        XCTAssertFalse(result.toast.message.contains("raw shell transcript"))
        XCTAssertFalse(result.activityEvent.message.contains("raw shell transcript"))
    }

    func testConsecutiveAdministratorCommandsAreBatchedIntoSingleExecution() async throws {
        let executor = RecordingSystemCommandExecutor()
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )
        let action = OptimizationAction(
            id: "power_saving_test",
            titleKey: "action.power_saving.title",
            descriptionKey: "action.power_saving.description",
            category: .monitoring,
            symbolName: "battery.100percent",
            statusFeatureID: nil,
            isRisky: false,
            estimatedTime: "5-10 seconds",
            requiresRestart: false,
            kind: .command([
                CommandRequest(command: "pmset -a lowpowermode 1", requiresAdministrator: true),
                CommandRequest(command: "pmset -a displaysleep 5", requiresAdministrator: true),
                CommandRequest(command: "pmset -a sleep 10", requiresAdministrator: true)
            ]),
            status: .ready,
            lastRunDescription: nil
        )

        _ = try await engine.execute(action)

        XCTAssertEqual(executor.requests.count, 1)
        XCTAssertEqual(
            executor.requests.first?.command,
            """
            pmset -a lowpowermode 1
            pmset -a displaysleep 5
            pmset -a sleep 10
            """
        )
    }

    func testCpuInspectionActionReturnsStructuredSummaryAndPreservesTranscript() async throws {
        let executor = MockSystemCommandExecutor(
            output: """
            CPU Model: Apple M2 Pro
            CPU Cores: 12
            CPU usage: 4.6% user, 9.1% sys, 86.3% idle
            """,
            exitCode: 0
        )
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )

        let action = OptimizationCatalog.actions().first(where: { $0.id == "system_check_cpu" })!
        let result = try await engine.execute(action)

        XCTAssertEqual(result.summary?.primaryValue, "Apple M2 Pro")
        XCTAssertEqual(result.summary?.secondaryValues.first?.value, "12")
        XCTAssertTrue(result.summary?.secondaryValues.last?.value.contains("86.3% idle") == true)
        XCTAssertTrue(result.debugLog?.contains("CPU Model: Apple M2 Pro") == true)
        XCTAssertEqual(result.toast.summaryLines.first, "Apple M2 Pro")
    }

    func testMemoryInspectionActionReturnsStructuredSummaryFromVmStatAndSwapUsage() async throws {
        let executor = MockSystemCommandExecutor(
            output: """
            Total RAM Bytes: 34359738368
            Swap Usage:
            vm.swapusage: total = 1024.00M  used = 256.00M  free = 768.00M  (encrypted)

            VM Stat:
            Mach Virtual Memory Statistics: (page size of 16384 bytes)
            Pages free: 16594.
            Pages active: 741849.
            Pages inactive: 708344.
            Pages speculative: 858.
            Pages throttled: 0.
            Pages wired down: 155884.
            Pages purgeable: 1236.
            File-backed pages: 486967.
            Anonymous pages: 964084.
            Pages occupied by compressor: 431964.
            """,
            exitCode: 0
        )
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )

        let action = OptimizationCatalog.actions().first(where: { $0.id == "system_check_memory" })!
        let result = try await engine.execute(action)

        XCTAssertTrue(result.summary?.primaryValue.contains("used") == true)
        XCTAssertEqual(result.summary?.secondaryValues[0].labelKey, .memorySnapshotCachedFiles)
        XCTAssertEqual(result.summary?.secondaryValues[1].labelKey, .memorySnapshotCompressed)
        XCTAssertEqual(result.summary?.secondaryValues[2].labelKey, .memorySnapshotSwapUsed)
        XCTAssertTrue(result.debugLog?.contains("vm.swapusage") == true)
    }

    func testMDMInspectionUsesProfilesReadoutAsCurrentVerdictAndCalculatesResetRisk() async throws {
        let executor = MockSystemCommandExecutor(
            output: """
            Historical local traces:
            DEP trace files: Present
            Historical MDM traces: Present

            Hosts advisory entries:
            0.0.0.0 deviceenrollment.apple.com
            0.0.0.0 mdmenrollment.apple.com
            0.0.0.0 iprofiles.apple.com

            Profiles enrollment readout (temporary hosts bypass disabled):
            profiles status -type enrollment:
            Enrolled via DEP: Yes
            MDM enrollment: Yes

            profiles show -type enrollment:
            Enrolled via DEP: Yes
            MDM enrollment: Yes

            profiles list:
            _computerlevel[1] attribute: profile.example

            profiles show -type configuration:
            profileIdentifier: com.example.mdm
            """,
            exitCode: 0
        )
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )

        let action = OptimizationCatalog.actions().first(where: { $0.id == "mdm_status" })!
        let result = try await engine.execute(action)

        XCTAssertEqual(result.summary?.primaryValue, "Currently enrolled")
        XCTAssertEqual(result.summary?.secondaryValues[0].value, "Yes")
        XCTAssertEqual(result.summary?.secondaryValues[1].value, "Yes")
        XCTAssertEqual(result.summary?.secondaryValues[2].value, "Likely yes")
        XCTAssertEqual(result.summary?.secondaryValues[3].value, "Warning: Possible MDM bypass hosts detected")
        XCTAssertEqual(result.summary?.secondaryValues.count, 4)
    }

    func testMDMInspectionRecognizesADEAssignmentEvenWhenCurrentEnrollmentIsNo() async throws {
        let executor = MockSystemCommandExecutor(
            output: """
            Historical local traces:
            DEP trace files: Present
            Historical MDM traces: Present

            Hosts advisory entries:
            0.0.0.0 deviceenrollment.apple.com
            0.0.0.0 mdmenrollment.apple.com
            0.0.0.0 iprofiles.apple.com

            Profiles enrollment readout (temporary hosts bypass disabled):
            profiles status -type enrollment:
            Enrolled via DEP: No
            MDM enrollment: No

            profiles show -type enrollment:
            Device Enrollment configuration:
            {
                ConfigurationURL = "https://illumio.jamfcloud.com/cloudenroll";
                IsMDMUnremovable = 1;
                IsMandatory = 1;
                MDMServerUID = deadbeef;
                OrganizationName = Illumio;
            }

            profiles list:
            There are no configuration profiles installed in the system domain

            profiles show -type configuration:
            There are no configuration profiles installed in the system domain
            """,
            exitCode: 0
        )
        let engine = OptimizationEngine(
            commandExecutor: executor,
            stateStore: InMemoryStateStore(),
            feedbackPresenter: ActionFeedbackPresenter(localizer: AppLocalizer(language: .english))
        )

        let action = OptimizationCatalog.actions().first(where: { $0.id == "mdm_status" })!
        let result = try await engine.execute(action)

        XCTAssertEqual(result.summary?.primaryValue, "Not currently enrolled")
        XCTAssertEqual(result.summary?.secondaryValues[0].value, "No")
        XCTAssertEqual(result.summary?.secondaryValues[1].value, "Yes")
        XCTAssertEqual(result.summary?.secondaryValues[2].value, "Likely yes")
        XCTAssertEqual(result.summary?.secondaryValues[3].value, "Warning: Possible MDM bypass hosts detected")
    }
}

private struct MockSystemCommandExecutor: SystemCommandExecuting {
    let output: String
    let exitCode: Int32

    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        CommandExecutionResult(output: output, exitCode: exitCode)
    }
}

private final class RecordingSystemCommandExecutor: SystemCommandExecuting {
    private(set) var requests: [CommandRequest] = []

    func execute(_ request: CommandRequest) async throws -> CommandExecutionResult {
        requests.append(request)
        return CommandExecutionResult(output: "", exitCode: 0)
    }
}

private final class InMemoryStateStore: StateStoreProtocol {
    private(set) var states: [String: FeatureState] = [:]

    func loadStates() throws -> [String: FeatureState] {
        states
    }

    func updateState(featureID: String, status: ActionStatus, timestamp: Date) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        states[featureID] = FeatureState(status: status.rawValue.lowercased(), timestamp: formatter.string(from: timestamp))
    }

    func removeState(featureID: String) throws {
        states[featureID] = nil
    }

    func resetStates() throws {
        states.removeAll()
    }
}
