import Foundation

protocol CPUMonitoringServiceProtocol {
    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<CPUMetrics>
    func stopMonitoring()
}

final class AdvancedCPUMonitoringService: CPUMonitoringServiceProtocol {
    private let sampleDelimiter = "\n__MBO_SAMPLE_END__\n"
    private let outputPrefix = "mbo-powermetrics-output-"
    private let stopPrefix = "mbo-powermetrics-stop-"

    private var monitoringTask: Task<Void, Never>?
    private var activeOutputURL: URL?
    private var activeStopSignalURL: URL?

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
            sampleIntervalMilliseconds: sampleIntervalMilliseconds
        )

        activeOutputURL = sessionFiles.outputURL
        activeStopSignalURL = sessionFiles.stopSignalURL

        return AsyncStream { continuation in
            monitoringTask = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                var lastDeliveredSample = ""

                while !Task.isCancelled {
                    do {
                        let output = try self.readOutput(from: sessionFiles.outputURL)

                        if let latestSample = Self.lastCompleteSample(
                            in: output,
                            delimiter: sampleDelimiter
                        ),
                           latestSample != lastDeliveredSample,
                           let metrics = CPUMetricsParser.parse(latestSample, cpuName: cpuName) {
                            lastDeliveredSample = latestSample
                            continuation.yield(metrics)
                        }

                        try await Task.sleep(nanoseconds: 500_000_000)
                    } catch {
                        if !Task.isCancelled {
                            print("CPU monitoring error: \(error)")
                        }
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

        if let stopSignalURL = activeStopSignalURL {
            fileManager.createFile(atPath: stopSignalURL.path, contents: Data())
        }

        activeStopSignalURL = nil
        activeOutputURL = nil
    }

    deinit {
        stopMonitoring()
    }

    private func startPrivilegedPowermetricsStream(
        outputURL: URL,
        stopSignalURL: URL,
        sampleIntervalMilliseconds: Int
    ) async throws {
        let shellCommand = Self.monitoringShellCommand(
            outputFilePath: outputURL.path,
            stopFilePath: stopSignalURL.path,
            sampleIntervalMilliseconds: sampleIntervalMilliseconds,
            sampleDelimiter: sampleDelimiter
        )

        _ = try await authService.executeShellCommandWithPrivileges(shellCommand)
    }

    private func readOutput(from url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func createSessionFiles() throws -> (outputURL: URL, stopSignalURL: URL) {
        let tempDirectory = fileManager.temporaryDirectory
        let outputURL = tempDirectory.appendingPathComponent("\(outputPrefix)\(UUID().uuidString).log")
        let stopSignalURL = tempDirectory.appendingPathComponent("\(stopPrefix)\(UUID().uuidString)")

        if !fileManager.createFile(atPath: outputURL.path, contents: Data()) {
            throw CPUMonitoringError.commandFailed
        }

        return (outputURL, stopSignalURL)
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
            guard name.hasPrefix(outputPrefix) || name.hasPrefix(stopPrefix) else {
                continue
            }

            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let modifiedAt = values?.contentModificationDate ?? .distantPast

            if modifiedAt < cutoffDate {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    static func monitoringShellCommand(
        outputFilePath: String,
        stopFilePath: String,
        sampleIntervalMilliseconds: Int,
        sampleDelimiter: String = "\n__MBO_SAMPLE_END__\n"
    ) -> String {
        let output = shellQuoted(outputFilePath)
        let stop = shellQuoted(stopFilePath)
        let delimiter = shellQuoted(sampleDelimiter)

        return """
        output_file=\(output); stop_file=\(stop); rm -f "$stop_file"; : > "$output_file"; /bin/sh -c 'while [ ! -f "$1" ]; do /usr/bin/powermetrics --samplers cpu_power,thermal -i "$2" --show-plimits --show-pstates -n 1; printf "%s" "$3"; done' sh "$stop_file" \(sampleIntervalMilliseconds) \(delimiter) >> "$output_file" 2>&1 </dev/null & printf 'started\\n'
        """
    }

    static func lastCompleteSample(in output: String, delimiter: String = "\n__MBO_SAMPLE_END__\n") -> String? {
        let components = output.components(separatedBy: delimiter)
        guard components.count >= 2 else { return nil }

        return components[components.count - 2]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
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
