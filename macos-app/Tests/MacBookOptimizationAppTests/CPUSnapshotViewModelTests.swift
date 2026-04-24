import XCTest
@testable import MacBookOptimizationApp

@MainActor
final class CPUSnapshotViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "cpuSnapshotRefreshInterval")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "cpuSnapshotRefreshInterval")
        super.tearDown()
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollNanoseconds: UInt64 = 25_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: pollNanoseconds)
        }
        XCTFail("Condition was not met before timeout")
    }

    func testStartMonitoringLoadsBasicMetricsWithoutStartingAdvancedService() async throws {
        let basicCollector = StubBasicCPUCollector(
            snapshots: [
                BasicCPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    cpuName: "Apple M3 Pro",
                    totalCores: 12,
                    overallUsage: 22.5,
                    thermalState: .nominal
                )
            ]
        )
        let advancedService = MockAdvancedCPUMonitoringService()
        let viewModel = CPUSnapshotViewModel(
            basicCollector: basicCollector,
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.basicMetrics?.cpuName, "Apple M3 Pro")
        XCTAssertEqual(viewModel.basicMetrics?.overallUsage, 22.5)
        XCTAssertEqual(viewModel.basicMetricsHistory.count, 1)
        XCTAssertEqual(advancedService.startCallCount, 0)
        XCTAssertEqual(viewModel.advancedState, .idle)
    }

    func testStartAdvancedMonitoringRequestsAdvancedStreamOnDemand() async throws {
        let basicCollector = StubBasicCPUCollector(
            snapshots: [
                BasicCPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    cpuName: "Apple M3 Pro",
                    totalCores: 12,
                    overallUsage: 22.5,
                    thermalState: .nominal
                )
            ]
        )
        let advancedMetrics = CPUMetrics(
            timestamp: Date(timeIntervalSince1970: 1_700_000_005),
            cpuName: "Apple M3 Pro",
            totalCores: 12,
            thermalPressure: .heavy,
            clusters: [],
            cores: [],
            power: .init(cpu: 1200, gpu: 350, ane: 40)
        )
        let advancedService = MockAdvancedCPUMonitoringService()
        advancedService.prepareOpenEndedStream(yielding: [advancedMetrics])
        let viewModel = CPUSnapshotViewModel(
            basicCollector: basicCollector,
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(advancedService.startCallCount, 1)
        XCTAssertEqual(viewModel.advancedMetrics?.power.cpu, 1200)
        XCTAssertEqual(viewModel.advancedState, .running)
    }

    func testAdvancedAuthorizationCancellationKeepsBasicMetricsAndMarksAdvancedDenied() async throws {
        let basicCollector = StubBasicCPUCollector(
            snapshots: [
                BasicCPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    cpuName: "Apple M3",
                    totalCores: 8,
                    overallUsage: 14.0,
                    thermalState: .moderate
                )
            ]
        )
        let advancedService = MockAdvancedCPUMonitoringService()
        advancedService.errorToThrow = AuthorizationError.commandFailed(output: "User canceled.")
        let viewModel = CPUSnapshotViewModel(
            basicCollector: basicCollector,
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.basicMetrics?.cpuName, "Apple M3")
        XCTAssertEqual(viewModel.advancedState, .denied)
        XCTAssertNil(viewModel.advancedMetrics)
    }

    func testUpdateRefreshIntervalRestartsBasicAndAdvancedMonitoring() async throws {
        let basicCollector = StubBasicCPUCollector(
            snapshots: [
                BasicCPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    cpuName: "Apple M3 Pro",
                    totalCores: 12,
                    overallUsage: 22.5,
                    thermalState: .nominal
                )
            ]
        )
        let advancedMetrics = CPUMetrics(
            timestamp: Date(timeIntervalSince1970: 1_700_000_005),
            cpuName: "Apple M3 Pro",
            totalCores: 12,
            thermalPressure: .heavy,
            clusters: [],
            cores: [],
            power: .init(cpu: 1200, gpu: 350, ane: 40)
        )
        let advancedService = MockAdvancedCPUMonitoringService()
        advancedService.prepareOpenEndedStream(yielding: [advancedMetrics])
        let viewModel = CPUSnapshotViewModel(
            basicCollector: basicCollector,
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        viewModel.updateRefreshInterval(.thirtySeconds)
        try await waitUntil {
            advancedService.startCallCount == 2
                && advancedService.stopCallCount == 1
                && viewModel.advancedState == .running
        }

        XCTAssertEqual(viewModel.refreshInterval, .thirtySeconds)
        XCTAssertEqual(advancedService.startCallCount, 2)
        XCTAssertEqual(advancedService.stopCallCount, 1)
        XCTAssertEqual(viewModel.monitoringState, .running)
        XCTAssertEqual(viewModel.advancedState, .running)
    }

    func testPauseAndResumeMonitoringPreservesAdvancedSessionWithoutRestartingAuthorization() async throws {
        let basicCollector = StubBasicCPUCollector(
            snapshots: [
                BasicCPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    cpuName: "Apple M3 Pro",
                    totalCores: 12,
                    overallUsage: 22.5,
                    thermalState: .nominal
                )
            ]
        )
        let advancedMetrics = CPUMetrics(
            timestamp: Date(timeIntervalSince1970: 1_700_000_005),
            cpuName: "Apple M3 Pro",
            totalCores: 12,
            thermalPressure: .heavy,
            clusters: [],
            cores: [],
            power: .init(cpu: 1200, gpu: 350, ane: 40)
        )
        let advancedService = MockAdvancedCPUMonitoringService()
        advancedService.prepareOpenEndedStream(yielding: [advancedMetrics])
        let viewModel = CPUSnapshotViewModel(
            basicCollector: basicCollector,
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        viewModel.pauseMonitoring()
        viewModel.resumeMonitoring()

        XCTAssertEqual(viewModel.monitoringState, .running)
        XCTAssertEqual(viewModel.advancedState, .running)
        XCTAssertEqual(viewModel.advancedMetrics?.power.cpu, 1200)
        XCTAssertEqual(viewModel.currentMetrics?.power.cpu, 1200)
        XCTAssertEqual(viewModel.metricsHistory.count, 1)
        XCTAssertEqual(advancedService.startCallCount, 1)
        XCTAssertEqual(advancedService.stopCallCount, 0)
    }

    func testAdvancedInsightsSummarizeDominantClusterCoreAndPower() async throws {
        let advancedMetrics = CPUMetrics(
            timestamp: Date(timeIntervalSince1970: 1_700_000_005),
            cpuName: "Apple M3 Pro",
            totalCores: 12,
            thermalPressure: .heavy,
            clusters: [
                .init(
                    id: "E-Cluster",
                    name: "E-Cluster",
                    online: 100,
                    activeFrequency: 1800,
                    activeResidency: 72,
                    idleResidency: 18,
                    downResidency: 10,
                    frequencyDistribution: [
                        .init(frequency: 1200, percentage: 30),
                        .init(frequency: 1800, percentage: 70)
                    ]
                ),
                .init(
                    id: "P0-Cluster",
                    name: "P0-Cluster",
                    online: 100,
                    activeFrequency: 3200,
                    activeResidency: 48,
                    idleResidency: 36,
                    downResidency: 16,
                    frequencyDistribution: [
                        .init(frequency: 2400, percentage: 35),
                        .init(frequency: 3200, percentage: 65)
                    ]
                )
            ],
            cores: [
                .init(id: 0, frequency: 1100, activeResidency: 31, idleResidency: 49, downResidency: 20),
                .init(id: 1, frequency: 3650, activeResidency: 87, idleResidency: 8, downResidency: 5),
                .init(id: 2, frequency: 2800, activeResidency: 62, idleResidency: 24, downResidency: 14)
            ],
            power: .init(cpu: 1800, gpu: 420, ane: 80)
        )
        let advancedService = MockAdvancedCPUMonitoringService()
        advancedService.prepareOpenEndedStream(yielding: [advancedMetrics])
        let viewModel = CPUSnapshotViewModel(
            basicCollector: StubBasicCPUCollector.singleSnapshot(),
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.advancedInsights.count, 3)
        XCTAssertEqual(viewModel.advancedInsights[0].title, "Most active cluster")
        XCTAssertEqual(viewModel.advancedInsights[0].value, "72%")
        XCTAssertEqual(viewModel.advancedInsights[0].detail, "E-Cluster carries current load")
        XCTAssertEqual(viewModel.advancedInsights[1].title, "Peak core")
        XCTAssertEqual(viewModel.advancedInsights[1].value, "3.65 GHz")
        XCTAssertEqual(viewModel.advancedInsights[1].detail, "CPU 1 is highest right now")
        XCTAssertEqual(viewModel.advancedInsights[2].title, "Power draw")
        XCTAssertEqual(viewModel.advancedInsights[2].value, "2.30 W")
        XCTAssertEqual(viewModel.advancedInsights[2].detail, "CPU dominates package usage")
        XCTAssertEqual(viewModel.selectedFrequencyCluster?.name, "E-Cluster")
        XCTAssertEqual(viewModel.observedFrequencyRange?.lowerBound, 1100)
        XCTAssertEqual(viewModel.observedFrequencyRange?.upperBound, 3650)
    }

    func testSelectedFrequencyClusterFallsBackToFirstClusterWithDistribution() {
        let viewModel = CPUSnapshotViewModel(
            basicCollector: StubBasicCPUCollector.singleSnapshot(),
            advancedMonitoringService: MockAdvancedCPUMonitoringService()
        )

        viewModel.advancedMetrics = CPUMetrics(
            timestamp: Date(timeIntervalSince1970: 1_700_000_005),
            cpuName: "Apple M3 Pro",
            totalCores: 12,
            thermalPressure: .moderate,
            clusters: [
                .init(
                    id: "E-Cluster",
                    name: "E-Cluster",
                    online: 100,
                    activeFrequency: 1500,
                    activeResidency: 50,
                    idleResidency: 30,
                    downResidency: 20,
                    frequencyDistribution: []
                ),
                .init(
                    id: "P0-Cluster",
                    name: "P0-Cluster",
                    online: 100,
                    activeFrequency: 3100,
                    activeResidency: 44,
                    idleResidency: 40,
                    downResidency: 16,
                    frequencyDistribution: [
                        .init(frequency: 2200, percentage: 45),
                        .init(frequency: 3100, percentage: 55)
                    ]
                )
            ],
            cores: [
                .init(id: 0, frequency: 1800, activeResidency: 40, idleResidency: 40, downResidency: 20)
            ],
            power: .init(cpu: 1200, gpu: 300, ane: 50)
        )

        XCTAssertEqual(viewModel.selectedFrequencyCluster?.name, "P0-Cluster")
    }

    func testCPUUsageChartDataKeepsBasicHistoryUntilAdvancedHistoryHasEnoughPoints() {
        let viewModel = CPUSnapshotViewModel(
            basicCollector: StubBasicCPUCollector.singleSnapshot(),
            advancedMonitoringService: MockAdvancedCPUMonitoringService()
        )

        viewModel.basicMetricsHistory = [
            BasicCPUMetrics(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                cpuName: "Apple M3 Pro",
                totalCores: 12,
                overallUsage: 18,
                thermalState: .nominal
            ),
            BasicCPUMetrics(
                timestamp: Date(timeIntervalSince1970: 1_700_000_015),
                cpuName: "Apple M3 Pro",
                totalCores: 12,
                overallUsage: 24,
                thermalState: .nominal
            )
        ]

        viewModel.advancedMetricsHistory = [
            CPUMetrics(
                timestamp: Date(timeIntervalSince1970: 1_700_000_030),
                cpuName: "Apple M3 Pro",
                totalCores: 12,
                thermalPressure: .moderate,
                clusters: [],
                cores: [],
                power: .init(cpu: 1200, gpu: 300, ane: 50)
            )
        ]

        XCTAssertEqual(viewModel.cpuUsageChartData.map(\.1), [18, 24])
    }

    func testCPUUsageChartDataSwitchesToAdvancedHistoryOnceTwoValidSamplesArrive() {
        let viewModel = CPUSnapshotViewModel(
            basicCollector: StubBasicCPUCollector.singleSnapshot(),
            advancedMonitoringService: MockAdvancedCPUMonitoringService()
        )

        viewModel.basicMetricsHistory = [
            BasicCPUMetrics(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                cpuName: "Apple M3 Pro",
                totalCores: 12,
                overallUsage: 18,
                thermalState: .nominal
            ),
            BasicCPUMetrics(
                timestamp: Date(timeIntervalSince1970: 1_700_000_015),
                cpuName: "Apple M3 Pro",
                totalCores: 12,
                overallUsage: 24,
                thermalState: .nominal
            )
        ]

        viewModel.advancedMetricsHistory = [
            CPUMetrics(
                timestamp: Date(timeIntervalSince1970: 1_700_000_030),
                cpuName: "Apple M3 Pro",
                totalCores: 12,
                thermalPressure: .moderate,
                clusters: [],
                cores: [
                    .init(id: 0, frequency: 1800, activeResidency: 52, idleResidency: 30, downResidency: 18)
                ],
                power: .init(cpu: 1200, gpu: 300, ane: 50)
            ),
            CPUMetrics(
                timestamp: Date(timeIntervalSince1970: 1_700_000_045),
                cpuName: "Apple M3 Pro",
                totalCores: 12,
                thermalPressure: .moderate,
                clusters: [],
                cores: [
                    .init(id: 0, frequency: 2100, activeResidency: 64, idleResidency: 24, downResidency: 12)
                ],
                power: .init(cpu: 1350, gpu: 330, ane: 60)
            )
        ]

        XCTAssertEqual(viewModel.cpuUsageChartData.map(\.1), [52, 64])
    }

}

private struct StubBasicCPUCollector: BasicCPUSnapshotCollecting {
    let snapshots: [BasicCPUMetrics]
    private var currentIndex = 0

    init(snapshots: [BasicCPUMetrics]) {
        self.snapshots = snapshots
    }

    func collectSnapshot() throws -> BasicCPUMetrics {
        snapshots[min(currentIndex, snapshots.count - 1)]
    }

    static func singleSnapshot() -> StubBasicCPUCollector {
        StubBasicCPUCollector(
            snapshots: [
                BasicCPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    cpuName: "Apple M3 Pro",
                    totalCores: 12,
                    overallUsage: 22.5,
                    thermalState: .nominal
                )
            ]
        )
    }
}

private final class MockAdvancedCPUMonitoringService: CPUMonitoringServiceProtocol {
    var startCallCount = 0
    var stopCallCount = 0
    var streamFactory: () -> AsyncStream<CPUMetrics> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    var streamToReturn: AsyncStream<CPUMetrics> {
        get { streamFactory() }
        set { streamFactory = { newValue } }
    }
    var errorToThrow: Error?
    private var continuation: AsyncStream<CPUMetrics>.Continuation?

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<CPUMetrics> {
        startCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return streamFactory()
    }

    func stopMonitoring() {
        stopCallCount += 1
        continuation?.finish()
        continuation = nil
    }

    func prepareOpenEndedStream(yielding metrics: [CPUMetrics]) {
        streamFactory = {
            AsyncStream { continuation in
                self.continuation = continuation
                for metric in metrics {
                    continuation.yield(metric)
                }
                continuation.onTermination = { [weak self] _ in
                    self?.continuation = nil
                }
            }
        }
    }
}
