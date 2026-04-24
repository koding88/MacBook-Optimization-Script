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
                    liveTelemetry: .init(
                        title: "Live telemetry unavailable",
                        detail: "Public API unavailable."
                    )
                )
            )
        )
        let viewModel = GPUSnapshotViewModel(
            provider: provider,
            displayObserver: MockGPUDisplayConfigurationObserver()
        )

        viewModel.startMonitoring()

        XCTAssertEqual(viewModel.currentMetrics?.devices.first?.name, "Apple M4")
        XCTAssertEqual(viewModel.currentMetrics?.displays.count, 1)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.monitoringState, GPUSnapshotViewModel.MonitoringState.running)
    }

    func testRefreshSurfacesCollectorError() {
        let provider = StubGPUSnapshotProvider(result: .failure(TestGPUError.failed))
        let viewModel = GPUSnapshotViewModel(provider: provider, displayObserver: MockGPUDisplayConfigurationObserver())

        viewModel.startMonitoring()

        XCTAssertNil(viewModel.currentMetrics)
        XCTAssertEqual(viewModel.error, TestGPUError.failed.localizedDescription)
        XCTAssertEqual(viewModel.monitoringState, .notStarted)
    }

    func testDisplayConfigurationChangeInvalidatesAndRefreshesSnapshot() {
        let provider = CountingGPUSnapshotProvider()
        let observer = MockGPUDisplayConfigurationObserver()
        let viewModel = GPUSnapshotViewModel(provider: provider, displayObserver: observer)

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
            displayObserver: observer
        )

        viewModel.startMonitoring()
        XCTAssertEqual(observer.startCount, 1)

        viewModel.stopMonitoring()

        XCTAssertEqual(observer.stopCount, 1)
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
            liveTelemetry: .init(
                title: "Live telemetry unavailable",
                detail: "Public API unavailable."
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
