import Foundation

@MainActor
final class CPUSnapshotViewModel: ObservableObject {
    struct AdvancedInsight: Equatable {
        let title: String
        let value: String
        let detail: String
    }

    enum AdvancedState: Equatable {
        case idle
        case requestingAuthorization
        case running
        case denied
        case failed(String)
    }

    enum MonitoringState {
        case notStarted
        case running
        case paused
    }

    @Published var basicMetrics: BasicCPUMetrics?
    @Published var basicMetricsHistory: [BasicCPUMetrics] = []
    @Published var advancedMetrics: CPUMetrics?
    @Published var advancedMetricsHistory: [CPUMetrics] = []
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
    @Published var advancedState: AdvancedState = .idle
    @Published var selectedFrequencyClusterID: String?

    private let basicCollector: BasicCPUSnapshotCollecting
    private let advancedMonitoringService: CPUMonitoringServiceProtocol
    private var monitoringTask: Task<Void, Never>?
    private var advancedMonitoringTask: Task<Void, Never>?
    private let maxHistoryCount = 60 // Keep 60 data points for charts
    private var isPaused: Bool = false

    enum RefreshInterval: Int, CaseIterable, Identifiable {
        case fiveSeconds = 5
        case fifteenSeconds = 15
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300
        
        var id: Int { rawValue }

        var localizationKey: LocalizedKey {
            switch self {
            case .fiveSeconds: return .cpuSnapshotRefreshIntervalFiveSeconds
            case .fifteenSeconds: return .cpuSnapshotRefreshIntervalFifteenSeconds
            case .thirtySeconds: return .cpuSnapshotRefreshIntervalThirtySeconds
            case .oneMinute: return .cpuSnapshotRefreshIntervalOneMinute
            case .fiveMinutes: return .cpuSnapshotRefreshIntervalFiveMinutes
            }
        }
        
        var timeInterval: TimeInterval {
            TimeInterval(rawValue)
        }
    }

    init(
        basicCollector: BasicCPUSnapshotCollecting = NativeBasicCPUCollector(),
        advancedMonitoringService: CPUMonitoringServiceProtocol = CPUMonitoringService()
    ) {
        self.basicCollector = basicCollector
        self.advancedMonitoringService = advancedMonitoringService

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
            while !Task.isCancelled {
                do {
                    let metrics = try basicCollector.collectSnapshot()
                    guard !Task.isCancelled else { break }

                    if !self.isPaused {
                        basicMetrics = metrics
                        basicMetricsHistory.append(metrics)

                        if basicMetricsHistory.count > maxHistoryCount {
                            basicMetricsHistory.removeFirst()
                        }
                    }

                    try await Task.sleep(nanoseconds: UInt64(refreshInterval.timeInterval * 1_000_000_000))
                } catch {
                    guard !Task.isCancelled else { break }
                    self.error = "Failed to start monitoring: \(error.localizedDescription)"
                    isMonitoring = false
                    monitoringState = .notStarted
                    break
                }
            }
        }
    }

    func startAdvancedMonitoring() {
        guard advancedState != .running else { return }

        if advancedMonitoringTask != nil || advancedState == .requestingAuthorization {
            stopAdvancedMonitoring(resetState: false)
        }
        advancedState = .requestingAuthorization

        advancedMonitoringTask = Task {
            do {
                let stream = try await advancedMonitoringService.startMonitoring(interval: refreshInterval.timeInterval)
                guard !Task.isCancelled else { return }

                advancedState = .running

                for await metrics in stream {
                    guard !Task.isCancelled else { break }

                    appendAdvancedMetrics(metrics)
                }

                if !Task.isCancelled, advancedState == .running {
                    advancedState = .idle
                }
            } catch {
                guard !Task.isCancelled else { return }
                if error.localizedDescription.localizedCaseInsensitiveContains("user canceled")
                    || error.localizedDescription.localizedCaseInsensitiveContains("user cancelled") {
                    advancedState = .denied
                } else {
                    advancedState = .failed(Self.sanitizedAdvancedErrorMessage(from: error))
                }
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
        stopAdvancedMonitoring(resetState: true)
        isMonitoring = false
        monitoringState = .notStarted
        isPaused = false
    }

    func updateRefreshInterval(_ interval: RefreshInterval) {
        guard refreshInterval != interval else { return }

        let wasMonitoring = monitoringState != .notStarted
        let wasPaused = monitoringState == .paused
        let shouldRestartAdvanced = advancedState == .running || advancedMetrics != nil

        refreshInterval = interval

        if wasMonitoring {
            stopMonitoring()
            startMonitoring()
            if wasPaused {
                pauseMonitoring()
            }
        }

        if shouldRestartAdvanced && !wasPaused {
            startAdvancedMonitoring()
        }
    }

    func stopAdvancedMonitoring(resetState: Bool = true) {
        advancedMonitoringTask?.cancel()
        advancedMonitoringTask = nil
        advancedMonitoringService.stopMonitoring()

        if resetState {
            advancedState = .idle
        }
    }

    var hasAdvancedMetrics: Bool {
        advancedMetrics != nil
    }

    // Chart data helpers
    var cpuUsageChartData: [(Date, Double)] {
        let advancedUsageData = advancedMetricsHistory
            .map { ($0.timestamp, $0.overallCPUUsage) }
            .filter { $0.1.isFinite }

        if advancedUsageData.count >= 2 {
            return advancedUsageData
        }

        return basicMetricsHistory.map { ($0.timestamp, $0.overallUsage) }
    }

    var clusterActivityData: [(String, Double)] {
        guard let metrics = advancedMetrics else { return [] }
        return metrics.clusters.map { ($0.name, $0.activeResidency) }
    }

    var coreFrequencies: [Int] {
        guard let metrics = advancedMetrics else { return [] }
        return metrics.cores.map { $0.frequency }
    }

    var selectedFrequencyCluster: CPUMetrics.ClusterMetrics? {
        guard let metrics = advancedMetrics else { return nil }

        if let selectedFrequencyClusterID,
           let selectedCluster = metrics.clusters.first(where: {
               $0.id == selectedFrequencyClusterID && !$0.frequencyDistribution.isEmpty
           }) {
            return selectedCluster
        }

        return metrics.clusters.first(where: { !$0.frequencyDistribution.isEmpty })
    }

    var observedFrequencyRange: ClosedRange<Int>? {
        let frequencies = coreFrequencies
        guard let minFrequency = frequencies.min(),
              let maxFrequency = frequencies.max() else {
            return nil
        }

        return minFrequency...maxFrequency
    }

    var advancedInsights: [AdvancedInsight] {
        guard let metrics = advancedMetrics else { return [] }

        var insights: [AdvancedInsight] = []

        if let busiestCluster = metrics.clusters.max(by: { $0.activeResidency < $1.activeResidency }) {
            insights.append(
                AdvancedInsight(
                    title: "Most Active Cluster",
                    value: "\(Int(busiestCluster.activeResidency.rounded()))%",
                    detail: "\(busiestCluster.name) carries current load"
                )
            )
        }

        if let peakCore = metrics.cores.max(by: { $0.frequency < $1.frequency }) {
            insights.append(
                AdvancedInsight(
                    title: "Peak Core",
                    value: Self.gigahertzString(forMHz: peakCore.frequency),
                    detail: "CPU \(peakCore.id) is highest right now"
                )
            )
        }

        insights.append(
            AdvancedInsight(
                title: "Power Draw",
                value: Self.wattsString(forMilliwatts: metrics.power.combined),
                detail: dominantPowerDetail(for: metrics.power)
            )
        )

        return insights
    }

    private static func sanitizedAdvancedErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "Unable to start advanced diagnostics."
        }

        if let commandFailedRange = message.range(of: "Command failed:", options: [.caseInsensitive]) {
            let detail = message[commandFailedRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? "Unable to start advanced diagnostics." : detail
        }

        return message
    }

    private func appendAdvancedMetrics(_ metrics: CPUMetrics) {
        advancedMetrics = metrics
        currentMetrics = metrics
        advancedMetricsHistory.append(metrics)
        metricsHistory.append(metrics)

        if selectedFrequencyClusterID == nil
            || !metrics.clusters.contains(where: {
                $0.id == selectedFrequencyClusterID && !$0.frequencyDistribution.isEmpty
            }) {
            selectedFrequencyClusterID = metrics.clusters.first(where: { !$0.frequencyDistribution.isEmpty })?.id
        }

        if advancedMetricsHistory.count > maxHistoryCount {
            advancedMetricsHistory.removeFirst()
        }

        if metricsHistory.count > maxHistoryCount {
            metricsHistory.removeFirst()
        }
    }

    private func dominantPowerDetail(for power: CPUMetrics.PowerMetrics) -> String {
        let cpu = power.cpu
        let gpu = power.gpu
        let ane = power.ane

        if cpu >= gpu && cpu >= ane {
            return "CPU dominates package usage"
        }

        if gpu >= cpu && gpu >= ane {
            return "GPU dominates package usage"
        }

        return "ANE dominates package usage"
    }

    private static func gigahertzString(forMHz frequency: Int) -> String {
        String(format: "%.2f GHz", Double(frequency) / 1000)
    }

    private static func wattsString(forMilliwatts value: Int) -> String {
        String(format: "%.2f W", Double(value) / 1000)
    }
}
