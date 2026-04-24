import Foundation

protocol CPUMonitoringServiceProtocol {
    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<CPUMetrics>
    func stopMonitoring()
}

final class AdvancedCPUMonitoringService: CPUMonitoringServiceProtocol {
    private let outputPrefix = "mbo-powermetrics-output-"
    private let stopPrefix = "mbo-powermetrics-stop-"
    private let pidPrefix = "mbo-powermetrics-pid-"
    private let workerExitPrefix = "__MBO_WORKER_EXIT__:"

    private var monitoringTask: Task<Void, Never>?
    private var activeOutputURL: URL?
    private var activeStopSignalURL: URL?
    private var activePIDURL: URL?
    private var activeWorkerPID: Int32?

    private let systemInfoProvider: SystemInfoProviding
    private let authService: AuthorizationService
    private let fileManager: FileManager

    init(
        systemInfoProvider: SystemInfoProviding = SystemInfoProvider(),
        authService: AuthorizationService = .shared,
        fileManager: FileManager = .default
    ) {
        self.systemInfoProvider = systemInfoProvider
        self.authService = authService
        self.fileManager = fileManager
    }

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<CPUMetrics> {
        stopMonitoring()
        cleanupStaleArtifacts()

        let sampleIntervalMilliseconds = max(Int(interval * 1_000), 1_000)
        let machineSummary = await systemInfoProvider.machineSummary()
        let cpuName = machineSummary.chipName

        let sessionFiles = try createSessionFiles()
        try await startPrivilegedPowermetricsStream(
            outputURL: sessionFiles.outputURL,
            stopSignalURL: sessionFiles.stopSignalURL,
            pidURL: sessionFiles.pidURL,
            sampleIntervalMilliseconds: sampleIntervalMilliseconds
        )

        activeOutputURL = sessionFiles.outputURL
        activeStopSignalURL = sessionFiles.stopSignalURL
        activePIDURL = sessionFiles.pidURL
        activeWorkerPID = try await waitForWorkerPID(at: sessionFiles.pidURL)
        return AsyncStream { continuation in
            monitoringTask = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                var pendingData = Data()
                var lastDeliveredSignature: Int?
                var lastReadOffset = 0

                while !Task.isCancelled {
                    do {
                        let chunk = try self.readIncrementalData(
                            from: sessionFiles.outputURL,
                            lastReadOffset: &lastReadOffset
                        )
                        if !chunk.isEmpty {
                            pendingData.append(chunk)
                        }

                        if Self.consumeWorkerExitStatus(
                            from: &pendingData,
                            marker: self.workerExitPrefix
                        ) != nil {
                            break
                        }

                        let samples = Self.consumeCompletePlistDocuments(from: &pendingData)
                        for sample in samples {
                            let signature = sample.hashValue
                            if signature != lastDeliveredSignature,
                               let metrics = CPUMetricsParser.parse(plistData: sample, cpuName: cpuName) {
                                lastDeliveredSignature = signature
                                continuation.yield(metrics)
                            }
                        }

                        if let pid = self.activeWorkerPID,
                           !self.isProcessAlive(pid),
                           !self.isStopRequested(at: sessionFiles.stopSignalURL) {
                            break
                        }

                        try await Task.sleep(nanoseconds: 250_000_000)
                    } catch {
                        break
                    }
                }

                continuation.finish()
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil

        // Signal stop via file - powermetrics worker will exit gracefully
        if let stopSignalURL = activeStopSignalURL {
            fileManager.createFile(atPath: stopSignalURL.path, contents: Data())
        }

        // Don't call terminateActivePowermetricsIfNeeded() - avoid OSA prompt on app close
        // Worker checks stop signal every iteration and exits cleanly
        activeStopSignalURL = nil
        activeOutputURL = nil
        activePIDURL = nil
        activeWorkerPID = nil
    }

    deinit {
        // Cancel monitoring task but skip process termination to avoid OSA prompt on app close
        monitoringTask?.cancel()
        monitoringTask = nil
        
        if let stopSignalURL = activeStopSignalURL {
            fileManager.createFile(atPath: stopSignalURL.path, contents: Data())
        }
        
        // Don't call terminateActivePowermetricsIfNeeded() - let OS clean up orphaned processes
        activeStopSignalURL = nil
        activeOutputURL = nil
        activePIDURL = nil
        activeWorkerPID = nil
    }

    private func startPrivilegedPowermetricsStream(
        outputURL: URL,
        stopSignalURL: URL,
        pidURL: URL,
        sampleIntervalMilliseconds: Int
    ) async throws {
        let shellCommand = Self.monitoringShellCommand(
            outputFilePath: outputURL.path,
            stopFilePath: stopSignalURL.path,
            pidFilePath: pidURL.path,
            sampleIntervalMilliseconds: sampleIntervalMilliseconds,
            workerExitPrefix: workerExitPrefix
        )

        _ = try await authService.executeShellCommandWithPrivileges(shellCommand)
    }

    private func readIncrementalData(from url: URL, lastReadOffset: inout Int) throws -> Data {
        let data = try Data(contentsOf: url)
        guard data.count > lastReadOffset else {
            return Data()
        }

        let chunk = data.subdata(in: lastReadOffset..<data.count)
        lastReadOffset = data.count
        return chunk
    }

    private func createSessionFiles() throws -> (outputURL: URL, stopSignalURL: URL, pidURL: URL) {
        let tempDirectory = fileManager.temporaryDirectory
        let outputURL = tempDirectory.appendingPathComponent("\(outputPrefix)\(UUID().uuidString).log")
        let stopSignalURL = tempDirectory.appendingPathComponent("\(stopPrefix)\(UUID().uuidString)")
        let pidURL = tempDirectory.appendingPathComponent("\(pidPrefix)\(UUID().uuidString)")

        if !fileManager.createFile(atPath: outputURL.path, contents: Data()) {
            throw CPUMonitoringError.commandFailed
        }

        return (outputURL, stopSignalURL, pidURL)
    }

    private func cleanupStaleArtifacts() {
        let tempDirectory = fileManager.temporaryDirectory
        guard let contents = try? fileManager.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let cutoffDate = Date().addingTimeInterval(-3_600)

        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix(outputPrefix)
                || name.hasPrefix(stopPrefix)
                || name.hasPrefix(pidPrefix) else {
                continue
            }

            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let modifiedAt = values?.contentModificationDate ?? .distantPast

            if modifiedAt < cutoffDate {
                if name.hasPrefix(pidPrefix) {
                    terminatePowermetricsIfNeeded(from: url, reason: "stale artifact cleanup")
                }
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func terminateActivePowermetricsIfNeeded(reason: String) {
        guard let activePIDURL else { return }
        terminatePowermetricsIfNeeded(from: activePIDURL, reason: reason)
        try? fileManager.removeItem(at: activePIDURL)
    }

    private func terminatePowermetricsIfNeeded(from pidURL: URL, reason: String) {
        guard let pidString = try? String(contentsOf: pidURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(pidString),
              pid > 0 else {
            return
        }

        if isProcessAlive(pid) {
            Task { [authService] in
                let command = "kill -TERM \(pid) 2>/dev/null || true; sleep 1; kill -KILL \(pid) 2>/dev/null || true"
                _ = try? await authService.executeShellCommandWithPrivileges(command)
            }
        }
    }

    private func waitForWorkerPID(at pidURL: URL) async throws -> Int32? {
        for _ in 0..<20 {
            if let pidString = try? String(contentsOf: pidURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = Int32(pidString),
               pid > 0 {
                return pid
            }

            try await Task.sleep(nanoseconds: 100_000_000)
        }

        return nil
    }

    private func isProcessAlive(_ pid: Int32) -> Bool {
        errno = 0
        let result = kill(pid, 0)
        let errorCode = errno
        return Self.processExistsCheckSucceeded(result: result, errnoValue: errorCode)
    }

    private func isStopRequested(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    static func monitoringShellCommand(
        outputFilePath: String,
        stopFilePath: String,
        pidFilePath: String,
        sampleIntervalMilliseconds: Int,
        workerExitPrefix: String = "__MBO_WORKER_EXIT__:"
    ) -> String {
        let output = shellQuoted(outputFilePath)
        let stop = shellQuoted(stopFilePath)
        let pid = shellQuoted(pidFilePath)

        return """
        output_file=\(output); stop_file=\(stop); pid_file=\(pid); if [ -f "$pid_file" ]; then stale_pid="$(cat "$pid_file" 2>/dev/null)"; if [ -n "$stale_pid" ] && kill -0 "$stale_pid" 2>/dev/null; then kill -TERM "$stale_pid" 2>/dev/null || true; sleep 1; kill -KILL "$stale_pid" 2>/dev/null || true; fi; fi; rm -f "$stop_file" "$pid_file"; : > "$output_file"; interval_ms=\(sampleIntervalMilliseconds); /bin/sh -c 'printf "%s" "$$" > "$1"; exec /usr/bin/powermetrics --samplers cpu_power,thermal --format plist -i "$2" --show-plimits --show-pstates >> "$3" 2>&1 </dev/null' sh "$pid_file" "$interval_ms" "$output_file" >/dev/null 2>&1 & printf 'started\\n'
        """
    }

    static func consumeCompletePlistDocuments(from output: inout Data) -> [Data] {
        let startMarker = Data("<?xml".utf8)
        let endMarker = Data("</plist>".utf8)
        var documents: [Data] = []

        while let startRange = output.range(of: startMarker),
              let endRange = output.range(of: endMarker, options: [], in: startRange.lowerBound..<output.endIndex) {
            let documentEnd = endRange.upperBound
            let document = output[startRange.lowerBound..<documentEnd]
            documents.append(Data(document))

            var removalEnd = documentEnd
            while removalEnd < output.endIndex, output[removalEnd] == 0 || output[removalEnd] == 10 {
                removalEnd = output.index(after: removalEnd)
            }

            output.removeSubrange(output.startIndex..<removalEnd)
        }

        return documents
    }

    static func consumeWorkerExitStatus(from output: inout Data, marker: String = "__MBO_WORKER_EXIT__:") -> Int32? {
        guard let markerData = marker.data(using: .utf8),
              let range = output.range(of: markerData) else {
            return nil
        }

        let statusStart = range.upperBound
        let lineEnd = output[statusStart...].firstIndex(of: 10) ?? output.endIndex
        let statusData = output[statusStart..<lineEnd]
        let statusString = String(decoding: statusData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        let removalEnd = lineEnd < output.endIndex ? output.index(after: lineEnd) : lineEnd
        output.removeSubrange(range.lowerBound..<removalEnd)

        return Int32(statusString)
    }

    static func processExistsCheckSucceeded(result: Int32, errnoValue: Int32) -> Bool {
        result == 0 || errnoValue == EPERM
    }

    private static func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

enum CPUMonitoringError: Error {
    case parsingFailed
    case commandFailed
    case authorizationFailed
}
