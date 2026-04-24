import Foundation

protocol BatteryMonitoringServiceProtocol {
    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<BatteryMetrics>
    func stopMonitoring()
    func fetchCurrentMetrics() async throws -> BatteryMetrics
}

final class BatteryMonitoringService: BatteryMonitoringServiceProtocol, BatterySnapshotRefreshing {
    private var monitoringTask: Task<Void, Never>?
    private let collector: BatterySnapshotCollecting

    init(collector: BatterySnapshotCollecting = NativeBatterySnapshotCollector()) {
        self.collector = collector
    }

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<BatteryMetrics> {
        stopMonitoring()

        let initialMetrics = try await fetchCurrentMetrics()

        return AsyncStream { continuation in
            continuation.yield(initialMetrics)

            monitoringTask = Task {
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(max(interval, 1) * 1_000_000_000))
                        let metrics = try await self.fetchCurrentMetrics()
                        continuation.yield(metrics)
                    } catch {
                        if !Task.isCancelled {
                            print("Battery monitoring error: \(error)")
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

    func fetchCurrentMetrics() async throws -> BatteryMetrics {
        try collector.collectSnapshot()
    }
}

enum BatteryMonitoringError: LocalizedError {
    case snapshotUnavailable

    var errorDescription: String? {
        switch self {
        case .snapshotUnavailable:
            return "Unable to read battery metrics from the system."
        }
    }
}
