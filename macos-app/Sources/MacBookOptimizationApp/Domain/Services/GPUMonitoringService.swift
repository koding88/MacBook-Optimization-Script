import Foundation

protocol GPUMonitoringServiceProtocol {
    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<GPUMetrics>
    func stopMonitoring()
}

final class GPUMonitoringService: GPUMonitoringServiceProtocol {
    private let advancedService: AdvancedGPUMonitoringService

    init(advancedService: AdvancedGPUMonitoringService = AdvancedGPUMonitoringService()) {
        self.advancedService = advancedService
    }

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<GPUMetrics> {
        try await advancedService.startMonitoring(interval: interval)
    }

    func stopMonitoring() {
        advancedService.stopMonitoring()
    }

    static func monitoringShellCommand(
        outputFilePath: String,
        stopFilePath: String,
        sampleIntervalMilliseconds: Int
    ) -> String {
        AdvancedGPUMonitoringService.monitoringShellCommand(
            outputFilePath: outputFilePath,
            stopFilePath: stopFilePath,
            pidFilePath: "/tmp/mbo-gpu-powermetrics.pid",
            sampleIntervalMilliseconds: sampleIntervalMilliseconds
        )
    }
}

final class AdvancedGPUMonitoringService: GPUMonitoringServiceProtocol {
    private let outputPrefix = "mbo-gpu-output-"
    private let stopPrefix = "mbo-gpu-stop-"
    private let pidPrefix = "mbo-gpu-pid-"

    private var monitoringTask: Task<Void, Never>?
    private var activeOutputURL: URL?
    private var activeStopSignalURL: URL?
    private var activePIDURL: URL?
    private var activeWorkerPID: Int32?

    private let authService: AuthorizationService
    private let fileManager: FileManager

    init(
        authService: AuthorizationService = .shared,
        fileManager: FileManager = .default
    ) {
        self.authService = authService
        self.fileManager = fileManager
    }

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<GPUMetrics> {
        stopMonitoring()
        cleanupStaleArtifacts()

        let sampleIntervalMilliseconds = max(Int(interval * 1_000), 1_000)
        let sessionFiles = try createSessionFiles()
        let shellCommand = Self.monitoringShellCommand(
            outputFilePath: sessionFiles.outputURL.path,
            stopFilePath: sessionFiles.stopSignalURL.path,
            pidFilePath: sessionFiles.pidURL.path,
            sampleIntervalMilliseconds: sampleIntervalMilliseconds
        )
        _ = try await authService.executeShellCommandWithPrivileges(shellCommand)

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
                var lastReadOffset = 0
                var lastDeliveredSignature: Int?

                while !Task.isCancelled {
                    do {
                        let chunk = try self.readIncrementalData(
                            from: sessionFiles.outputURL,
                            lastReadOffset: &lastReadOffset
                        )

                        if !chunk.isEmpty {
                            pendingData.append(chunk)
                        }

                        let textSamples = Self.consumeCompleteTextSamples(from: &pendingData)
                        for sample in textSamples {
                            let signature = sample.hashValue
                            if signature != lastDeliveredSignature,
                               let metrics = GPUMetricsParser.parse(sample) {
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

        // Don't call terminatePowermetricsIfNeeded() - avoid OSA prompt on app close
        // Worker checks stop signal every iteration and exits cleanly
        if let pidURL = activePIDURL {
            try? fileManager.removeItem(at: pidURL)
        }

        activeOutputURL = nil
        activeStopSignalURL = nil
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
        
        // Don't call terminatePowermetricsIfNeeded() - let OS clean up orphaned processes
        activeOutputURL = nil
        activeStopSignalURL = nil
        activePIDURL = nil
        activeWorkerPID = nil
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

    private func readIncrementalData(from url: URL, lastReadOffset: inout Int) throws -> Data {
        let data = try Data(contentsOf: url)
        guard data.count > lastReadOffset else { return Data() }
        let chunk = data.subdata(in: lastReadOffset..<data.count)
        lastReadOffset = data.count
        return chunk
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
                    terminatePowermetricsIfNeeded(from: url)
                }
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func terminatePowermetricsIfNeeded(from pidURL: URL) {
        guard let pidString = try? String(contentsOf: pidURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
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

    private func isProcessAlive(_ pid: Int32) -> Bool {
        errno = 0
        let result = kill(pid, 0)
        return Self.processExistsCheckSucceeded(result: result, errnoValue: errno)
    }

    private func isStopRequested(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    static func monitoringShellCommand(
        outputFilePath: String,
        stopFilePath: String,
        pidFilePath: String,
        sampleIntervalMilliseconds: Int
    ) -> String {
        let output = shellQuoted(outputFilePath)
        let stop = shellQuoted(stopFilePath)
        let pid = shellQuoted(pidFilePath)

        return """
        output_file=\(output); stop_file=\(stop); pid_file=\(pid); if [ -f "$pid_file" ]; then stale_pid="$(cat "$pid_file" 2>/dev/null)"; if [ -n "$stale_pid" ] && kill -0 "$stale_pid" 2>/dev/null; then kill -TERM "$stale_pid" 2>/dev/null || true; sleep 1; kill -KILL "$stale_pid" 2>/dev/null || true; fi; fi; rm -f "$stop_file" "$pid_file"; : > "$output_file"; interval_ms=\(sampleIntervalMilliseconds); /bin/sh -c 'printf "%s" "$$" > "$1"; exec /usr/bin/powermetrics --samplers gpu_power -i "$2" >> "$3" 2>&1 </dev/null' sh "$pid_file" "$interval_ms" "$output_file" >/dev/null 2>&1 & printf 'started\\n'
        """
    }

    static func consumeCompleteTextSamples(from output: inout Data) -> [String] {
        let divider = Data("*** Sampled system activity".utf8)
        var samples: [String] = []

        while let firstRange = output.range(of: divider) {
            guard let nextRange = output.range(of: divider, options: [], in: firstRange.upperBound..<output.endIndex) else {
                break
            }

            let sampleData = output[firstRange.lowerBound..<nextRange.lowerBound]
            let sample = String(decoding: sampleData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sample.isEmpty {
                samples.append(sample)
            }

            output.removeSubrange(output.startIndex..<nextRange.lowerBound)
        }

        if let text = String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty,
           text.contains("*** Sampled system activity"),
           (text.contains("**** GPU usage ****") || text.contains("GPU Power:")) {
            samples.append(text)
            output.removeAll()
        }

        return samples
    }

    static func processExistsCheckSucceeded(result: Int32, errnoValue: Int32) -> Bool {
        result == 0 || errnoValue == EPERM
    }

    private static func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
