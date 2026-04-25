import Foundation

protocol MemoryMonitoringServiceProtocol {
    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<MemoryMetrics>
    func stopMonitoring()
    func fetchCurrentMetrics() throws -> MemoryMetrics
}

final class MemoryMonitoringService: MemoryMonitoringServiceProtocol {
    private let snapshotCollector: MemorySnapshotCollecting
    private var monitoringTask: Task<Void, Never>?

    init(snapshotCollector: MemorySnapshotCollecting = NativeMemorySnapshotCollector()) {
        self.snapshotCollector = snapshotCollector
    }

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<MemoryMetrics> {
        stopMonitoring()

        let initialMetrics = try snapshotCollector.collectSnapshot()

        return AsyncStream { continuation in
            continuation.yield(initialMetrics)

            monitoringTask = Task {
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(max(interval, 1) * 1_000_000_000))
                        let metrics = try snapshotCollector.collectSnapshot()
                        continuation.yield(metrics)
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

    func fetchCurrentMetrics() throws -> MemoryMetrics {
        try snapshotCollector.collectSnapshot()
    }
}

enum MemoryMonitoringError: LocalizedError {
    case commandFailed(String)
    case parsingFailed
    case nativeCollectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let output):
            return output.isEmpty ? "Memory monitoring command failed." : output
        case .parsingFailed:
            return "Unable to parse memory metrics."
        case .nativeCollectionFailed(let message):
            return message
        }
    }
}
