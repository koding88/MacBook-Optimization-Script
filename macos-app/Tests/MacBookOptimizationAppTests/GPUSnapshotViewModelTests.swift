import XCTest
@testable import MacBookOptimizationApp

@MainActor
final class GPUSnapshotViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "gpuSnapshotRefreshInterval")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "gpuSnapshotRefreshInterval")
        super.tearDown()
    }

    func testStartMonitoringLoadsStaticSnapshot() {
        let provider = StubGPUSnapshotProvider(
            result: .success(
                GPUSnapshotMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    devices: [
                        .init(
                            id: "gpu0",
                            name: "Apple M4",
                            metalSupport: "Supported",
                            displayCount: 1,
                            hasUnifiedMemory: true,
                            recommendedMaxWorkingSetSizeBytes: 12_000_000_000,
                            supportedFamilies: ["Apple8"]
                        )
                    ],
                    displays: [
                        .init(
                            id: "display0",
                            name: "Built-in Display",
                            resolution: "3024 × 1964",
                            refreshRate: "120Hz",
                            scaleDescription: "1512 × 982 scaled",
                            colorDepth: nil,
                            supportsHDR: true,
                            supportsProMotion: true,
                            isOnline: true,
                            isMain: true
                        )
                    ],
                    gpuMetrics: .init(
                        title: GPUSnapshotMetrics.defaultMetricsTitle,
                        detail: nil,
                        metrics: nil
                    )
                )
            )
        )
        let viewModel = GPUSnapshotViewModel(
            provider: provider,
            displayObserver: MockGPUDisplayConfigurationObserver(),
            advancedMonitoringService: MockAdvancedGPUMonitoringService()
        )

        viewModel.startMonitoring()

        XCTAssertEqual(viewModel.currentMetrics?.devices.first?.name, "Apple M4")
        XCTAssertEqual(viewModel.currentMetrics?.displays.count, 1)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.monitoringState, GPUSnapshotViewModel.MonitoringState.running)
    }

    func testRefreshSurfacesCollectorError() {
        let provider = StubGPUSnapshotProvider(result: .failure(TestGPUError.failed))
        let viewModel = GPUSnapshotViewModel(
            provider: provider,
            displayObserver: MockGPUDisplayConfigurationObserver(),
            advancedMonitoringService: MockAdvancedGPUMonitoringService()
        )

        viewModel.startMonitoring()

        XCTAssertNil(viewModel.currentMetrics)
        XCTAssertEqual(viewModel.error, TestGPUError.failed.localizedDescription)
        XCTAssertEqual(viewModel.monitoringState, GPUSnapshotViewModel.MonitoringState.notStarted)
    }

    func testDisplayConfigurationChangeInvalidatesAndRefreshesSnapshot() {
        let provider = CountingGPUSnapshotProvider()
        let observer = MockGPUDisplayConfigurationObserver()
        let viewModel = GPUSnapshotViewModel(
            provider: provider,
            displayObserver: observer,
            advancedMonitoringService: MockAdvancedGPUMonitoringService()
        )

        viewModel.startMonitoring()
        XCTAssertEqual(provider.collectCount, 1)
        XCTAssertEqual(viewModel.refreshGeneration, 1)

        observer.trigger()

        XCTAssertEqual(provider.collectCount, 2)
        XCTAssertEqual(viewModel.refreshGeneration, 2)
    }

    func testStopMonitoringStopsDisplayObservation() {
        let observer = MockGPUDisplayConfigurationObserver()
        let viewModel = GPUSnapshotViewModel(
            provider: StubGPUSnapshotProvider(result: .success(Self.sampleMetrics)),
            displayObserver: observer,
            advancedMonitoringService: MockAdvancedGPUMonitoringService()
        )

        viewModel.startMonitoring()
        XCTAssertEqual(observer.startCount, 1)

        viewModel.stopMonitoring()

        XCTAssertEqual(observer.stopCount, 1)
    }

    func testStartAdvancedMonitoringRequestsGpuMetricsOnDemand() async throws {
        let advancedService = MockAdvancedGPUMonitoringService()
        advancedService.prepareOpenEndedStream(
            yielding: [
                GPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_010),
                    powerMilliwatts: 420,
                    frequencyMHz: 744,
                    usagePercent: 18.5,
                    memoryBytes: nil,
                    processes: [
                        .init(id: "WindowServer", name: "WindowServer", gpuMillisecondsPerSecond: 120)
                    ]
                )
            ]
        )
        let viewModel = GPUSnapshotViewModel(
            provider: StubGPUSnapshotProvider(result: .success(Self.sampleMetrics)),
            displayObserver: MockGPUDisplayConfigurationObserver(),
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.advancedState, .running)
        XCTAssertEqual(viewModel.currentMetrics?.gpuMetrics.metrics?.powerMilliwatts, 420)
        XCTAssertEqual(advancedService.startCallCount, 1)
    }

    func testAdvancedAuthorizationCancellationMarksStateDenied() async throws {
        let advancedService = MockAdvancedGPUMonitoringService()
        advancedService.errorToThrow = AuthorizationError.commandFailed(output: "User canceled.")
        let viewModel = GPUSnapshotViewModel(
            provider: StubGPUSnapshotProvider(result: .success(Self.sampleMetrics)),
            displayObserver: MockGPUDisplayConfigurationObserver(),
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.advancedState, .denied)
        XCTAssertNil(viewModel.currentMetrics?.gpuMetrics.metrics)
    }

    func testAdvancedLoadingOverlayStopsAfterAuthorizationWhenNoSampleArrivesYet() async throws {
        let advancedService = MockAdvancedGPUMonitoringService()
        advancedService.prepareOpenEndedStream(yielding: [])
        let viewModel = GPUSnapshotViewModel(
            provider: StubGPUSnapshotProvider(result: .success(Self.sampleMetrics)),
            displayObserver: MockGPUDisplayConfigurationObserver(),
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.advancedState, .running)
        XCTAssertTrue(viewModel.shouldShowAdvancedLoadingOverlay)
        XCTAssertTrue(viewModel.isWaitingForFirstAdvancedSample)
    }

    func testRefreshAdvancedMetricsRestartsRuntimeSamplingWithoutReloadingStaticSnapshot() async throws {
        let provider = CountingGPUSnapshotProvider()
        let advancedService = MockAdvancedGPUMonitoringService()
        advancedService.prepareOpenEndedStream(
            yielding: [
                GPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_010),
                    powerMilliwatts: 420,
                    frequencyMHz: 744,
                    usagePercent: 18.5,
                    memoryBytes: nil,
                    processes: [
                        .init(id: "WindowServer", name: "WindowServer", gpuMillisecondsPerSecond: 120)
                    ]
                )
            ]
        )
        let viewModel = GPUSnapshotViewModel(
            provider: provider,
            displayObserver: MockGPUDisplayConfigurationObserver(),
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(provider.collectCount, 1)
        XCTAssertEqual(advancedService.startCallCount, 1)

        viewModel.refreshAdvancedMetrics()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(provider.collectCount, 1)
        XCTAssertEqual(advancedService.stopCallCount, 1)
        XCTAssertEqual(advancedService.startCallCount, 2)
    }

    func testUpdateRefreshIntervalRestartsAdvancedMonitoringWhenRunning() async throws {
        let advancedService = MockAdvancedGPUMonitoringService()
        advancedService.prepareOpenEndedStream(
            yielding: [
                GPUMetrics(
                    timestamp: Date(timeIntervalSince1970: 1_700_000_010),
                    powerMilliwatts: 420,
                    frequencyMHz: 744,
                    usagePercent: 18.5,
                    memoryBytes: nil,
                    processes: []
                )
            ]
        )
        let viewModel = GPUSnapshotViewModel(
            provider: StubGPUSnapshotProvider(result: .success(Self.sampleMetrics)),
            displayObserver: MockGPUDisplayConfigurationObserver(),
            advancedMonitoringService: advancedService
        )

        viewModel.startMonitoring()
        viewModel.startAdvancedMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(advancedService.startCallCount, 1)

        viewModel.updateRefreshInterval(.thirtySeconds)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(advancedService.stopCallCount, 1)
        XCTAssertEqual(advancedService.startCallCount, 2)
    }
}

private extension GPUSnapshotViewModelTests {
    static var sampleMetrics: GPUSnapshotMetrics {
        GPUSnapshotMetrics(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            devices: [
                .init(
                    id: "gpu0",
                    name: "Apple M4",
                    metalSupport: "Supported",
                    displayCount: 1,
                    hasUnifiedMemory: true,
                    recommendedMaxWorkingSetSizeBytes: 12_000_000_000,
                    supportedFamilies: ["Apple8"]
                )
            ],
            displays: [
                .init(
                    id: "display0",
                    name: "Built-in Display",
                    resolution: "3024 × 1964",
                    refreshRate: "120Hz",
                    scaleDescription: "1512 × 982 scaled",
                    colorDepth: nil,
                    supportsHDR: true,
                    supportsProMotion: true,
                    isOnline: true,
                    isMain: true
                )
            ],
            gpuMetrics: .init(
                title: GPUSnapshotMetrics.defaultMetricsTitle,
                detail: nil,
                metrics: nil
            )
        )
    }
}

private struct StubGPUSnapshotProvider: GPUSnapshotProviding {
    let result: Result<GPUSnapshotMetrics, Error>

    func collectSnapshot() throws -> GPUSnapshotMetrics {
        try result.get()
    }
}

private final class CountingGPUSnapshotProvider: GPUSnapshotProviding {
    var collectCount = 0

    func collectSnapshot() throws -> GPUSnapshotMetrics {
        collectCount += 1
        return GPUSnapshotViewModelTests.sampleMetrics
    }
}

private final class MockAdvancedGPUMonitoringService: GPUMonitoringServiceProtocol {
    var startCallCount = 0
    var stopCallCount = 0
    var errorToThrow: Error?
    var streamFactory: () -> AsyncStream<GPUMetrics> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    private var continuation: AsyncStream<GPUMetrics>.Continuation?

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<GPUMetrics> {
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

    func prepareOpenEndedStream(yielding metrics: [GPUMetrics]) {
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

private final class MockGPUDisplayConfigurationObserver: GPUDisplayConfigurationObserving {
    var startCount = 0
    var stopCount = 0
    private var handler: (@MainActor () -> Void)?

    func startObserving(_ handler: @escaping @MainActor () -> Void) {
        startCount += 1
        self.handler = handler
    }

    func stopObserving() {
        stopCount += 1
        handler = nil
    }

    func trigger() {
        handler?()
    }
}

private enum TestGPUError: LocalizedError {
    case failed

    var errorDescription: String? {
        "GPU collector failed."
    }
}
