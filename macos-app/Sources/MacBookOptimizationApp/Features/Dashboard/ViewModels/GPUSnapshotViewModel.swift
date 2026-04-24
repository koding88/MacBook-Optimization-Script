import Foundation

@MainActor
final class GPUSnapshotViewModel: ObservableObject {
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

    @Published var currentMetrics: GPUSnapshotMetrics?
    @Published var refreshInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: "gpuSnapshotRefreshInterval")
        }
    }
    @Published var isMonitoring = false
    @Published var error: String?
    @Published var monitoringState: MonitoringState = .notStarted
    @Published var advancedState: AdvancedState = .idle

    private let provider: GPUSnapshotProviding
    private let displayObserver: GPUDisplayConfigurationObserving
    private let advancedMonitoringService: GPUMonitoringServiceProtocol
    private var isPaused = false
    private(set) var refreshGeneration = 0
    private var advancedMonitoringTask: Task<Void, Never>?

    enum RefreshInterval: Int, CaseIterable, Identifiable {
        case fiveSeconds = 5
        case fifteenSeconds = 15
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300

        var id: Int { rawValue }

        var localizationKey: LocalizedKey {
            switch self {
            case .fiveSeconds: return .gpuSnapshotRefreshIntervalFiveSeconds
            case .fifteenSeconds: return .gpuSnapshotRefreshIntervalFifteenSeconds
            case .thirtySeconds: return .gpuSnapshotRefreshIntervalThirtySeconds
            case .oneMinute: return .gpuSnapshotRefreshIntervalOneMinute
            case .fiveMinutes: return .gpuSnapshotRefreshIntervalFiveMinutes
            }
        }

        var timeInterval: TimeInterval {
            TimeInterval(rawValue)
        }
    }

    init(
        provider: GPUSnapshotProviding,
        displayObserver: GPUDisplayConfigurationObserving,
        advancedMonitoringService: GPUMonitoringServiceProtocol
    ) {
        self.provider = provider
        self.displayObserver = displayObserver
        self.advancedMonitoringService = advancedMonitoringService

        let savedInterval = UserDefaults.standard.integer(forKey: "gpuSnapshotRefreshInterval")
        self.refreshInterval = RefreshInterval(rawValue: savedInterval) ?? .fifteenSeconds
    }

    convenience init() {
        self.init(
            provider: NativeGPUSnapshotProvider(),
            displayObserver: GPUDisplayConfigurationObserver(),
            advancedMonitoringService: GPUMonitoringService()
        )
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
        displayObserver.startObserving { [weak self] in
            self?.handleDisplayConfigurationChange()
        }
        refresh()
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
    }

    func stopMonitoring() {
        stopAdvancedMonitoring(resetState: true)
        displayObserver.stopObserving()
        isMonitoring = false
        monitoringState = .notStarted
        isPaused = false
    }

    func updateRefreshInterval(_ interval: RefreshInterval) {
        guard refreshInterval != interval else { return }

        let shouldRestartAdvanced = advancedState == .running

        refreshInterval = interval

        if shouldRestartAdvanced {
            refreshAdvancedMetrics()
        }
    }

    func refreshAdvancedMetrics() {
        guard !isPaused else { return }
        startAdvancedMonitoring(forceRestart: true)
    }

    func startAdvancedMonitoring(forceRestart: Bool = false) {
        if !forceRestart, advancedState == .running {
            return
        }

        if advancedMonitoringTask != nil || advancedState == .requestingAuthorization || forceRestart {
            stopAdvancedMonitoring(resetState: false)
        }
        setAdvancedMetricsStatus(detail: "requestingAuthorization", metrics: nil)
        advancedState = .requestingAuthorization

        advancedMonitoringTask = Task {
            do {
                let stream = try await advancedMonitoringService.startMonitoring(interval: refreshInterval.timeInterval)
                guard !Task.isCancelled else { return }

                advancedState = .running
                setAdvancedMetricsStatus(detail: "waitingForFirstSample", metrics: nil)

                for await metrics in stream {
                    guard !Task.isCancelled else { break }
                    appendAdvancedMetrics(metrics)
                }

                if !Task.isCancelled, advancedState == .running {
                    setAdvancedMetricsStatus(detail: nil, metrics: nil)
                    advancedState = .idle
                }
            } catch {
                guard !Task.isCancelled else { return }
                if error.localizedDescription.localizedCaseInsensitiveContains("user canceled")
                    || error.localizedDescription.localizedCaseInsensitiveContains("user cancelled") {
                    setAdvancedMetricsStatus(detail: "denied", metrics: nil)
                    advancedState = .denied
                } else {
                    setAdvancedMetricsStatus(detail: Self.sanitizedAdvancedErrorMessage(from: error), metrics: nil)
                    advancedState = .failed(Self.sanitizedAdvancedErrorMessage(from: error))
                }
            }
        }
    }

    func stopAdvancedMonitoring(resetState: Bool = true) {
        advancedMonitoringTask?.cancel()
        advancedMonitoringTask = nil
        advancedMonitoringService.stopMonitoring()

        if resetState {
            setAdvancedMetricsStatus(detail: nil, metrics: nil)
            advancedState = .idle
        }
    }

    var shouldShowAdvancedLoadingOverlay: Bool {
        advancedState == .requestingAuthorization || isWaitingForFirstAdvancedSample
    }

    var isWaitingForFirstAdvancedSample: Bool {
        advancedState == .running && currentMetrics?.gpuMetrics.metrics == nil
    }

    func refresh() {
        guard !isPaused else { return }

        do {
            currentMetrics = try provider.collectSnapshot()
            refreshGeneration += 1
            error = nil
            isMonitoring = true
        } catch {
            self.error = Self.sanitizedErrorMessage(from: error)
            isMonitoring = false
            monitoringState = .notStarted
        }
    }

    private func handleDisplayConfigurationChange() {
        guard monitoringState == .running, !isPaused else { return }
        refresh()
    }

    private func appendAdvancedMetrics(_ metrics: GPUMetrics) {
        setAdvancedMetricsStatus(detail: nil, metrics: metrics)
    }

    private func setAdvancedMetricsStatus(detail: String?, metrics: GPUMetrics?) {
        guard let existingMetrics = currentMetrics else { return }
        currentMetrics = GPUSnapshotMetrics(
            timestamp: existingMetrics.timestamp,
            devices: existingMetrics.devices,
            displays: existingMetrics.displays,
            gpuMetrics: .init(
                title: GPUSnapshotMetrics.defaultMetricsTitle,
                detail: detail,
                metrics: metrics
            )
        )
    }

    private static func sanitizedErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "Unable to load GPU snapshot."
        }
        return message
    }

    private static func sanitizedAdvancedErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "Unable to start GPU metrics."
        }

        if let commandFailedRange = message.range(of: "Command failed:", options: [.caseInsensitive]) {
            let detail = message[commandFailedRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? "Unable to start GPU metrics." : detail
        }

        return message
    }
}
