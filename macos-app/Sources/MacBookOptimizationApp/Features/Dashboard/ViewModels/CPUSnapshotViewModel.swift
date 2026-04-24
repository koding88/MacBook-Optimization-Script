import Foundation
import Combine

@MainActor
final class CPUSnapshotViewModel: ObservableObject {
    enum MonitoringState {
        case notStarted
        case running
        case paused
    }
    
    @Published var currentMetrics: CPUMetrics?
    @Published var metricsHistory: [CPUMetrics] = []
    @Published var refreshInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: "cpuSnapshotRefreshInterval")
        }
    }
    @Published var isMonitoring: Bool = false
    @Published var error: String?
    @Published var monitoringState: MonitoringState = .notStarted
    
    private let monitoringService: CPUMonitoringServiceProtocol
    private var monitoringTask: Task<Void, Never>?
    private let maxHistoryCount = 60 // Keep 60 data points for charts
    private var isPaused: Bool = false
    
    enum RefreshInterval: Int, CaseIterable, Identifiable {
        case fiveSeconds = 5
        case fifteenSeconds = 15
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .fiveSeconds: return "5 seconds"
            case .fifteenSeconds: return "15 seconds"
            case .thirtySeconds: return "30 seconds"
            case .oneMinute: return "1 minute"
            case .fiveMinutes: return "5 minutes"
            }
        }
        
        var timeInterval: TimeInterval {
            TimeInterval(rawValue)
        }
    }
    
    init(monitoringService: CPUMonitoringServiceProtocol = CPUMonitoringService()) {
        self.monitoringService = monitoringService
        
        // Restore saved refresh interval
        let savedInterval = UserDefaults.standard.integer(forKey: "cpuSnapshotRefreshInterval")
        if let interval = RefreshInterval(rawValue: savedInterval) {
            self.refreshInterval = interval
        } else {
            self.refreshInterval = .fifteenSeconds
        }
    }
    
    func startMonitoring() {
        guard monitoringState == .notStarted else {
            // Already started, just resume if paused
            if monitoringState == .paused {
                resumeMonitoring()
            }
            return
        }
        
        isMonitoring = true
        monitoringState = .running
        isPaused = false
        error = nil
        
        monitoringTask = Task {
            do {
                let stream = try await monitoringService.startMonitoring(interval: refreshInterval.timeInterval)
                
                for await metrics in stream {
                    guard !Task.isCancelled else { break }
                    
                    // Skip updates if paused
                    if self.isPaused {
                        continue
                    }
                    
                    currentMetrics = metrics
                    metricsHistory.append(metrics)
                    
                    // Keep only recent history
                    if metricsHistory.count > maxHistoryCount {
                        metricsHistory.removeFirst()
                    }
                }
            } catch {
                self.error = "Failed to start monitoring: \(error.localizedDescription)"
                isMonitoring = false
                monitoringState = .notStarted
            }
        }
    }
    
    func pauseMonitoring() {
        guard monitoringState == .running else { return }
        
        isPaused = true
        monitoringState = .paused
        // Don't stop the monitoring task or service - just pause UI updates
    }
    
    func resumeMonitoring() {
        guard monitoringState == .paused else { return }
        
        isPaused = false
        monitoringState = .running
        isMonitoring = true
        // Monitoring task is still running, just resume UI updates
    }
    
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        monitoringService.stopMonitoring()
        isMonitoring = false
        monitoringState = .notStarted
        isPaused = false
    }
    
    func updateRefreshInterval(_ interval: RefreshInterval) {
        let wasMonitoring = monitoringState != .notStarted
        
        // Always stop completely when changing interval
        // because we need to restart powermetrics with new parameters
        if wasMonitoring {
            stopMonitoring()
        }
        
        refreshInterval = interval
        
        // Restart monitoring if it was running
        // This will require password again (expected behavior)
        if wasMonitoring {
            startMonitoring()
        }
    }
    
    // Chart data helpers
    var cpuUsageChartData: [(Date, Double)] {
        metricsHistory.map { ($0.timestamp, $0.overallCPUUsage) }
    }
    
    var clusterActivityData: [(String, Double)] {
        guard let metrics = currentMetrics else { return [] }
        return metrics.clusters.map { ($0.name, $0.activeResidency) }
    }
    
    var coreFrequencies: [Int] {
        guard let metrics = currentMetrics else { return [] }
        return metrics.cores.map { $0.frequency }
    }
}
