import Foundation

@MainActor
final class MemorySnapshotViewModel: ObservableObject {
    enum MonitoringState {
        case notStarted
        case running
        case paused
    }
    
    @Published var currentMetrics: MemoryMetrics?
    @Published var metricsHistory: [MemoryMetrics] = []
    @Published var refreshInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: "memorySnapshotRefreshInterval")
        }
    }
    @Published var isMonitoring = false
    @Published var error: String?
    @Published var monitoringState: MonitoringState = .notStarted

    private let monitoringService: MemoryMonitoringServiceProtocol
    private var monitoringTask: Task<Void, Never>?
    private let maxHistoryCount = 60
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

    init(monitoringService: MemoryMonitoringServiceProtocol = MemoryMonitoringService()) {
        self.monitoringService = monitoringService

        let savedInterval = UserDefaults.standard.integer(forKey: "memorySnapshotRefreshInterval")
        if let interval = RefreshInterval(rawValue: savedInterval) {
            self.refreshInterval = interval
        } else {
            self.refreshInterval = .fiveSeconds
        }
    }

    func startMonitoring() {
        guard monitoringState == .notStarted else {
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

                    if self.isPaused {
                        continue
                    }

                    currentMetrics = metrics
                    metricsHistory.append(metrics)

                    if metricsHistory.count > maxHistoryCount {
                        metricsHistory.removeFirst()
                    }
                }
            } catch {
                self.error = error.localizedDescription
                isMonitoring = false
                monitoringState = .notStarted
            }
        }
    }

    func pauseMonitoring() {
        guard monitoringState == .running else { return }
        
        isPaused = true
        monitoringState = .paused
    }
    
    func resumeMonitoring() {
        guard monitoringState == .paused else { return }
        
        isPaused = false
        monitoringState = .running
        isMonitoring = true
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
        if wasMonitoring {
            stopMonitoring()
        }

        refreshInterval = interval

        if wasMonitoring {
            startMonitoring()
        }
    }

    var pressureHistory: [(Date, Double)] {
        metricsHistory.map { ($0.timestamp, $0.pressureScore) }
    }
}
