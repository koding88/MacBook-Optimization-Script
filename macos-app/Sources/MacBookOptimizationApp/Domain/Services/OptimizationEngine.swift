import Foundation

final class OptimizationEngine: OptimizationExecuting {
    private struct InspectionPresentation {
        let summary: ActionResultSummary
        let symbolName: String?
    }

    private let commandExecutor: SystemCommandExecuting
    private let stateStore: StateStoreProtocol
    private let feedbackPresenter: any ActionFeedbackPresenting
    private let localizer: AppLocalizer

    init(
        commandExecutor: SystemCommandExecuting,
        stateStore: StateStoreProtocol,
        feedbackPresenter: any ActionFeedbackPresenting = ActionFeedbackPresenter(
            localizer: AppLocalizer(language: .english)
        ),
        localizer: AppLocalizer = AppLocalizer(language: .english)
    ) {
        self.commandExecutor = commandExecutor
        self.stateStore = stateStore
        self.feedbackPresenter = feedbackPresenter
        self.localizer = localizer
    }

    func execute(_ action: OptimizationAction) async throws -> ActionExecutionResult {
        let context = SystemContext(commandExecutor: commandExecutor, stateStore: stateStore)
        let status: ActionStatus
        let result: ActionExecutionResult

        switch action.kind {
        case .command(let requests):
            let commandResult = try await executeCommands(requests)
            status = commandResult.exitCode == 0 ? .enabled : .failed
            result = presentCommandFeedback(for: action, status: status, commandResult: commandResult)
        case .dynamic(let resolver):
            let requests = try await resolver(context)
            let commandResult = try await executeCommands(requests)
            status = commandResult.exitCode == 0 ? .enabled : .failed
            result = presentCommandFeedback(for: action, status: status, commandResult: commandResult)
        case .manual(let instructions):
            status = .enabled
            result = ActionExecutionResult(output: instructions, status: status)
        case .statuses:
            let states = try stateStore.loadStates()
            status = .enabled
            result = ActionExecutionResult(output: render(states: states), status: status)
        }

        if let featureID = action.statusFeatureID {
            try stateStore.updateState(featureID: featureID, status: status, timestamp: .now)
        }

        return result
    }

    private func presentCommandFeedback(
        for action: OptimizationAction,
        status: ActionStatus,
        commandResult: CommandExecutionResult
    ) -> ActionExecutionResult {
        guard status != .failed,
              let inspection = inspectionPresentation(for: action, output: commandResult.output) else {
            return feedbackPresenter.presentMutation(
                action: action,
                status: status,
                debugLog: commandResult.output
            )
        }

        return feedbackPresenter.presentInspection(
            action: action,
            summary: inspection.summary,
            debugLog: commandResult.output,
            symbolName: inspection.symbolName ?? action.symbolName
        )
    }

    private func executeCommands(_ requests: [CommandRequest]) async throws -> CommandExecutionResult {
        var combinedOutput: [String] = []
        var finalExitCode: Int32 = 0

        for request in coalescedRequests(requests) {
            let result = try await commandExecutor.execute(request)
            if !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                combinedOutput.append("$ \(request.command)\n\(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                combinedOutput.append("$ \(request.command)")
            }

            finalExitCode = result.exitCode
            if result.exitCode != 0 {
                break
            }
        }

        return CommandExecutionResult(output: combinedOutput.joined(separator: "\n\n"), exitCode: finalExitCode)
    }

    private func coalescedRequests(_ requests: [CommandRequest]) -> [CommandRequest] {
        guard !requests.isEmpty else { return [] }

        var batched: [CommandRequest] = []
        var current = requests[0]

        for request in requests.dropFirst() {
            if request.requiresAdministrator == current.requiresAdministrator {
                current = CommandRequest(
                    command: current.command + "\n" + request.command,
                    requiresAdministrator: current.requiresAdministrator
                )
            } else {
                batched.append(current)
                current = request
            }
        }

        batched.append(current)
        return batched
    }

    private func render(states: [String: FeatureState]) -> String {
        guard !states.isEmpty else {
            return "No optimizations have been run yet."
        }

        return states
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key): \(value.status) | \(value.timestamp)"
            }
            .joined(separator: "\n")
    }

    private func inspectionPresentation(for action: OptimizationAction, output: String) -> InspectionPresentation? {
        switch action.id {
        case "system_check_cpu":
            return cpuInspectionPresentation(output: output)
        case "system_check_memory":
            return memoryInspectionPresentation(output: output)
        case "system_check_battery":
            return batteryInspectionPresentation(output: output)
        case "system_check_gpu":
            return gpuInspectionPresentation(output: output)
        case "system_check_disk":
            return diskInspectionPresentation(output: output)
        case "system_check_network":
            return networkInspectionPresentation(output: output)
        case "mdm_status":
            return mdmInspectionPresentation(output: output)
        default:
            return nil
        }
    }

    private func cpuInspectionPresentation(output: String) -> InspectionPresentation? {
        let lines = outputLines(from: output)
        let model = value(after: "CPU Model:", in: lines)
        let cores = value(after: "CPU Cores:", in: lines)
        let usage = value(after: "CPU usage:", in: lines)

        guard let primaryValue = model ?? usage ?? cores else { return nil }

        var secondaryValues: [ActionResultSummary.LineItem] = []
        if let cores, cores != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotCPUCores, value: cores))
        }
        if let usage, usage != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotCPUUsage, value: usage))
        }

        return InspectionPresentation(
            summary: ActionResultSummary(
                primaryValue: primaryValue,
                secondaryValues: secondaryValues
            ),
            symbolName: "cpu"
        )
    }

    private func memoryInspectionPresentation(output: String) -> InspectionPresentation? {
        let lines = outputLines(from: output)
        let totalRAM = value(after: "Total RAM:", in: lines)
        let pageSize = pageSize(in: lines)
        let pagesFree = pageCount(after: "Pages free:", in: lines)
        let compressedPages = pageCount(after: "Pages occupied by compressor:", in: lines)

        guard let primaryValue = totalRAM
            ?? byteCountString(forPages: pagesFree, pageSize: pageSize)
            ?? byteCountString(forPages: compressedPages, pageSize: pageSize) else {
            return nil
        }

        var secondaryValues: [ActionResultSummary.LineItem] = []
        if let free = byteCountString(forPages: pagesFree, pageSize: pageSize), free != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotMemoryFree, value: free))
        }
        if let compressed = byteCountString(forPages: compressedPages, pageSize: pageSize), compressed != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotMemoryCompressed, value: compressed))
        }

        return InspectionPresentation(
            summary: ActionResultSummary(
                primaryValue: primaryValue,
                secondaryValues: secondaryValues
            ),
            symbolName: "memorychip.fill"
        )
    }

    private func batteryInspectionPresentation(output: String) -> InspectionPresentation? {
        let lines = outputLines(from: output)
        let batteryLine = lines.first { $0.contains("%") && ($0.contains("charging") || $0.contains("discharging") || $0.contains("charged")) }
        let percentage = firstPercentage(in: batteryLine ?? output)
        let powerSource = powerSource(in: lines)
        let chargingState = value(after: "Charging:", in: lines) ?? inferredBatteryState(from: batteryLine)
        let condition = value(after: "Condition:", in: lines)
        let cycleCount = value(after: "Cycle Count:", in: lines)

        guard let primaryValue = percentage ?? condition ?? powerSource ?? chargingState else { return nil }

        var secondaryValues: [ActionResultSummary.LineItem] = []
        if let powerSource, powerSource != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotBatteryPowerSource, value: powerSource))
        }
        if let chargingState, chargingState != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotBatteryState, value: chargingState))
        }
        if let condition, condition != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotBatteryCondition, value: condition))
        }
        if let cycleCount, cycleCount != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotBatteryCycleCount, value: cycleCount))
        }

        return InspectionPresentation(
            summary: ActionResultSummary(
                primaryValue: primaryValue,
                secondaryValues: secondaryValues
            ),
            symbolName: "battery.75percent"
        )
    }

    private func gpuInspectionPresentation(output: String) -> InspectionPresentation? {
        let lines = outputLines(from: output)
        let model = value(after: "GPU Model:", in: lines)
        let metalSupport = value(after: "Metal Support:", in: lines)

        guard let primaryValue = model ?? metalSupport else { return nil }

        var secondaryValues: [ActionResultSummary.LineItem] = []
        if let metalSupport, metalSupport != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotGPUMetal, value: metalSupport))
        }

        return InspectionPresentation(
            summary: ActionResultSummary(
                primaryValue: primaryValue,
                secondaryValues: secondaryValues
            ),
            symbolName: "display.2"
        )
    }

    private func diskInspectionPresentation(output: String) -> InspectionPresentation? {
        let lines = outputLines(from: output)
        let used = value(after: "Disk Used:", in: lines)
        let available = value(after: "Disk Available:", in: lines)
        let mountPoint = value(after: "Mount Point:", in: lines)

        guard let primaryValue = used ?? available ?? mountPoint else { return nil }

        var secondaryValues: [ActionResultSummary.LineItem] = []
        if let available, available != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotDiskAvailable, value: available))
        }
        if let mountPoint, mountPoint != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotDiskMountPoint, value: mountPoint))
        }

        return InspectionPresentation(
            summary: ActionResultSummary(
                primaryValue: primaryValue,
                secondaryValues: secondaryValues
            ),
            symbolName: "internaldrive"
        )
    }

    private func networkInspectionPresentation(output: String) -> InspectionPresentation? {
        let lines = outputLines(from: output)
        let activeInterface = value(after: "Active Interface:", in: lines)
        let gateway = value(after: "Gateway:", in: lines)
        let hardwarePort = value(after: "Hardware Port:", in: lines)

        guard let primaryValue = activeInterface ?? gateway ?? hardwarePort else { return nil }

        var secondaryValues: [ActionResultSummary.LineItem] = []
        if let gateway, gateway != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotNetworkGateway, value: gateway))
        }
        if let hardwarePort, hardwarePort != primaryValue {
            secondaryValues.append(.init(labelKey: .snapshotNetworkHardwarePort, value: hardwarePort))
        }

        return InspectionPresentation(
            summary: ActionResultSummary(
                primaryValue: primaryValue,
                secondaryValues: secondaryValues
            ),
            symbolName: "network"
        )
    }

    private func mdmInspectionPresentation(output: String) -> InspectionPresentation? {
        let normalized = output.lowercased()
        let profilesSection = sectionBodyToEnd(after: "Profiles enrollment readout (temporary hosts bypass disabled):", in: output)
        let historySection = sectionBody(after: "Historical local traces:", in: output)

        let profilesNormalized = profilesSection.lowercased()
        let historyNormalized = historySection.lowercased()

        let currentDEP = profilesNormalized.contains("enrolled via dep: yes")
        let currentEnrollment = profilesNormalized.contains("mdm enrollment: yes")
        let adeAssigned = currentDEP
            || profilesNormalized.contains("device enrollment configuration:")
            || profilesNormalized.contains("configurationurl =")
            || profilesNormalized.contains("ismandatory = 1;")
            || profilesNormalized.contains("ismdmunremovable = 1;")
        let historicalTracesFound = historyNormalized.contains("dep trace files: present")
            || historyNormalized.contains("historical mdm traces: present")
        let resetRisk: String

        let enrollmentStatus: String
        if currentEnrollment {
            enrollmentStatus = localizer.text(.mdmStatusCurrentlyEnrolled)
        } else if profilesNormalized.contains("mdm enrollment: no") {
            enrollmentStatus = localizer.text(.mdmStatusNotCurrentlyEnrolled)
        } else if adeAssigned {
            enrollmentStatus = localizer.text(.mdmStatusDepAdeAssigned)
        } else if historicalTracesFound {
            enrollmentStatus = localizer.text(.mdmStatusHistoricalTracesFound)
        } else {
            enrollmentStatus = localizer.text(.mdmStatusNeedsReview)
        }

        if currentEnrollment || adeAssigned {
            resetRisk = localizer.text(.mdmRiskLikelyYes)
        } else if profilesNormalized.contains("enrolled via dep: no") && profilesNormalized.contains("mdm enrollment: no") {
            resetRisk = localizer.text(.mdmRiskNoClearTrigger)
        } else if historicalTracesFound {
            resetRisk = localizer.text(.mdmRiskHistoricalTracesSuggestReview)
        } else {
            resetRisk = localizer.text(.mdmStatusNeedsReview)
        }

        let hasBypassHosts = normalized.contains("0.0.0.0 deviceenrollment.apple.com")
            || normalized.contains("0.0.0.0 mdmenrollment.apple.com")
            || normalized.contains("0.0.0.0 iprofiles.apple.com")

        let advisory = hasBypassHosts
            ? localizer.text(.mdmHostsWarningBypassDetected)
            : (normalized.contains("no mdm-related host overrides found")
                ? localizer.text(.mdmHostsNoBypassDetected)
                : localizer.text(.mdmHostsAdvisoryUnavailable))

        return InspectionPresentation(
            summary: ActionResultSummary(
                primaryValue: enrollmentStatus,
                secondaryValues: [
                    .init(labelKey: .snapshotMDMCurrentEnrollment, value: currentEnrollment ? localizer.text(.commonYes) : localizer.text(.commonNo)),
                    .init(labelKey: .snapshotMDMADEAssignment, value: adeAssigned ? localizer.text(.commonYes) : localizer.text(.commonNo)),
                    .init(labelKey: .snapshotMDMResetRisk, value: resetRisk),
                    .init(labelKey: .snapshotMDMHostsAdvisory, value: advisory)
                ]
            ),
            symbolName: "building.2.crop.circle"
        )
    }

    private func sectionBody(after header: String, in output: String) -> String {
        guard let headerRange = output.range(of: header) else {
            return ""
        }

        let remainder = output[headerRange.upperBound...]
        if let nextSectionRange = remainder.range(of: "\n\n") {
            return String(remainder[..<nextSectionRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sectionBodyToEnd(after header: String, in output: String) -> String {
        guard let headerRange = output.range(of: header) else {
            return ""
        }

        return String(output[headerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func outputLines(from output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix("$ ")
                    && !line.contains(".zshrc:")
                    && !line.contains("terminfo:")
            }
    }

    private func value(after prefix: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func pageSize(in lines: [String]) -> Int64? {
        guard let line = lines.first(where: { $0.contains("page size of") }) else { return nil }
        guard let start = line.range(of: "page size of ")?.upperBound,
              let end = line[start...].range(of: " bytes")?.lowerBound else {
            return nil
        }
        return Int64(line[start..<end])
    }

    private func pageCount(after prefix: String, in lines: [String]) -> Int64? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let digits = line.dropFirst(prefix.count).filter(\.isNumber)
        return Int64(String(digits))
    }

    private func byteCountString(forPages pageCount: Int64?, pageSize: Int64?) -> String? {
        guard let pageCount, let pageSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: pageCount * pageSize)
    }

    private func firstPercentage(in text: String) -> String? {
        let digits = text.split(separator: " ").first { token in token.contains("%") }
        return digits.map(String.init)
    }

    private func powerSource(in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix("Now drawing from") }) else { return nil }
        guard let firstQuote = line.firstIndex(of: "'"),
              let lastQuote = line.lastIndex(of: "'"),
              firstQuote < lastQuote else {
            return nil
        }
        return String(line[line.index(after: firstQuote)..<lastQuote])
    }

    private func inferredBatteryState(from batteryLine: String?) -> String? {
        guard let batteryLine else { return nil }
        let normalized = batteryLine.lowercased()
        if normalized.contains("charging") {
            return localizer.text(.batteryStateCharging)
        }
        if normalized.contains("discharging") {
            return localizer.text(.batteryStateDischarging)
        }
        if normalized.contains("charged") {
            return localizer.text(.batteryStateCharged)
        }
        return nil
    }
}
