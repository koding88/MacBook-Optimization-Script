import Foundation

protocol BatterySnapshotRefreshing {
    func fetchCurrentMetrics() async throws -> BatteryMetrics
}
