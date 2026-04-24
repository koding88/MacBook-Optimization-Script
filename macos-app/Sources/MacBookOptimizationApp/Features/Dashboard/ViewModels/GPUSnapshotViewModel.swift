import Foundation

@MainActor
final class GPUSnapshotViewModel: ObservableObject {
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

    private let provider: GPUSnapshotProviding
    private let displayObserver: GPUDisplayConfigurationObserving
    private var isPaused = false
    private(set) var refreshGeneration = 0

    enum RefreshInterval: Int, CaseIterable, Identifiable {
        case onOpen = 0

        var id: Int { rawValue }

        var localizationKey: LocalizedKey {
            .gpuSnapshotRefreshIntervalOnOpen
        }
    }

    init(
        provider: GPUSnapshotProviding,
        displayObserver: GPUDisplayConfigurationObserving
    ) {
        self.provider = provider
        self.displayObserver = displayObserver

        let savedInterval = UserDefaults.standard.integer(forKey: "gpuSnapshotRefreshInterval")
        self.refreshInterval = RefreshInterval(rawValue: savedInterval) ?? .onOpen
    }

    convenience init() {
        self.init(
            provider: NativeGPUSnapshotProvider(),
            displayObserver: GPUDisplayConfigurationObserver()
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
        displayObserver.stopObserving()
        isMonitoring = false
        monitoringState = .notStarted
        isPaused = false
    }

    func updateRefreshInterval(_ interval: RefreshInterval) {
        refreshInterval = interval
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

    private static func sanitizedErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "Unable to load GPU snapshot."
        }
        return message
    }
}
