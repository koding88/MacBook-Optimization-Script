import Foundation

protocol MemoryMonitoringServiceProtocol {
    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<MemoryMetrics>
    func stopMonitoring()
}

final class MemoryMonitoringService: MemoryMonitoringServiceProtocol {
    private var monitoringTask: Task<Void, Never>?

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<MemoryMetrics> {
        stopMonitoring()

        let initialOutput = try Self.executeSnapshotCommand()
        guard let initialMetrics = MemoryMetricsParser.parse(initialOutput) else {
            throw MemoryMonitoringError.parsingFailed
        }

        return AsyncStream { continuation in
            continuation.yield(initialMetrics)

            monitoringTask = Task {
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(max(interval, 1) * 1_000_000_000))
                        let output = try Self.executeSnapshotCommand()
                        if let metrics = MemoryMetricsParser.parse(output) {
                            continuation.yield(metrics)
                        }
                    } catch {
                        if !Task.isCancelled {
                            print("Memory monitoring error: \(error)")
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
    }

    static func executeSnapshotCommand() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = SystemCommandExecutor.regularShellArguments(for: MemorySnapshotCommand.combinedCommand)

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw MemoryMonitoringError.commandFailed(output)
        }

        return output
    }
}

enum MemoryMonitoringError: LocalizedError {
    case commandFailed(String)
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .commandFailed(let output):
            return output.isEmpty ? "Memory monitoring command failed." : output
        case .parsingFailed:
            return "Unable to parse memory metrics."
        }
    }
}
