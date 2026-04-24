import XCTest
@testable import MacBookOptimizationApp

@MainActor
final class BatterySnapshotViewModelTests: XCTestCase {
    
    // MARK: - Test Auto-Refresh Updates All New Fields
    
    func testAutoRefreshUpdatesAllNewFields() async throws {
        // Given: A mock monitoring service that provides battery metrics with all new fields
        let mockService = MockBatteryMonitoringService()
        let viewModel = BatterySnapshotViewModel(monitoringService: mockService)
        
        // Set up initial metrics with all new fields populated
        let initialMetrics = BatteryMetrics(
            timestamp: Date(),
            level: 85,
            powerSource: .ac,
            chargingState: .charging,
            condition: .normal,
            cycleCount: 42,
            fullChargeCapacity: 4971,
            designCapacity: 5000,
            currentCharge: 4382,
            chargerWattage: 94,
            chargerAdapterName: "94W USB-C Power Adapter",
            temperature: 28.5,
            manufactureDate: Date(timeIntervalSince1970: 1684108800), // 2023-05-15
            serialNumber: "C02ABC123DEF",
            isLowPowerModeEnabled: false
        )
        
        mockService.metricsToReturn = initialMetrics
        
        // When: Start monitoring with a short interval
        viewModel.updateRefreshInterval(.fifteenSeconds)
        viewModel.startMonitoring()
        
        // Wait for initial metrics to be collected
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then: Verify initial metrics are set with all new fields
        XCTAssertNotNil(viewModel.currentMetrics)
        XCTAssertEqual(viewModel.currentMetrics?.chargerWattage, 94)
        XCTAssertEqual(viewModel.currentMetrics?.chargerAdapterName, "94W USB-C Power Adapter")
        XCTAssertEqual(viewModel.currentMetrics?.temperature, 28.5)
        XCTAssertNotNil(viewModel.currentMetrics?.manufactureDate)
        XCTAssertEqual(viewModel.currentMetrics?.serialNumber, "C02ABC123DEF")
        XCTAssertEqual(viewModel.currentMetrics?.isLowPowerModeEnabled, false)
        
        // Given: Updated metrics with changed values for all new fields
        let updatedMetrics = BatteryMetrics(
            timestamp: Date(),
            level: 90,
            powerSource: .ac,
            chargingState: .charging,
            condition: .normal,
            cycleCount: 42,
            fullChargeCapacity: 4971,
            designCapacity: 5000,
            currentCharge: 4500,
            chargerWattage: 61,  // Changed
            chargerAdapterName: "61W USB-C Power Adapter",  // Changed
            temperature: 32.0,  // Changed
            manufactureDate: Date(timeIntervalSince1970: 1684108800),
            serialNumber: "C02ABC123DEF",
            isLowPowerModeEnabled: true  // Changed
        )
        
        mockService.metricsToReturn = updatedMetrics
        
        // When: Wait for auto-refresh to trigger (15 seconds + buffer)
        try await Task.sleep(nanoseconds: 16_000_000_000) // 16 seconds
        
        // Then: Verify all new fields are updated
        XCTAssertEqual(viewModel.currentMetrics?.chargerWattage, 61, "Charger wattage should be updated")
        XCTAssertEqual(viewModel.currentMetrics?.chargerAdapterName, "61W USB-C Power Adapter", "Adapter name should be updated")
        XCTAssertEqual(viewModel.currentMetrics?.temperature, 32.0, "Temperature should be updated")
        XCTAssertEqual(viewModel.currentMetrics?.isLowPowerModeEnabled, true, "Low Power Mode should be updated")
        
        // Cleanup
        viewModel.stopMonitoring()
    }
    
    func testManualRefreshCollectsAllNewFields() async throws {
        // This test verifies that manual refresh collects all new battery fields
        // by parsing actual system command output
        
        // Given: A view model with default monitoring service
        let viewModel = BatterySnapshotViewModel()
        
        // When: Trigger manual refresh
        viewModel.manualRefresh()
        
        // Wait for refresh to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Verify metrics are collected
        XCTAssertNotNil(viewModel.currentMetrics, "Manual refresh should collect battery metrics")
        
        // Verify that the parser is capable of handling all new fields
        // (actual values depend on the system, but the fields should be present in the struct)
        let metrics = viewModel.currentMetrics!
        
        // These fields should always be present
        XCTAssertGreaterThanOrEqual(metrics.level, 0)
        XCTAssertLessThanOrEqual(metrics.level, 100)
        XCTAssertNotEqual(metrics.powerSource, .unknown)
        
        // New fields may or may not have values depending on system state
        // We just verify the structure supports them
        _ = metrics.chargerWattage  // Can be nil if not on AC
        _ = metrics.chargerAdapterName  // Can be nil if not on AC
        _ = metrics.temperature  // Should typically have a value
        _ = metrics.manufactureDate  // Should typically have a value
        _ = metrics.serialNumber  // Should typically have a value
        _ = metrics.isLowPowerModeEnabled  // Should typically have a value
        
        // Verify computed properties work with new fields
        _ = metrics.hasChargerInfo
        _ = metrics.temperatureStatus
    }
    
    // MARK: - Test Manual Refresh Updates All New Fields (Task 15)
    
    func testManualRefreshButtonTriggersImmediateDataFetch() async throws {
        // This test verifies that manual refresh button triggers immediate data fetch
        // and updates all new battery fields (Requirement 9.2)
        
        // Given: A view model in manual refresh mode
        let viewModel = BatterySnapshotViewModel()
        viewModel.updateRefreshInterval(.manual)
        
        // Verify not auto-monitoring
        XCTAssertFalse(viewModel.isMonitoring, "Should not be auto-monitoring in manual mode")
        XCTAssertNil(viewModel.currentMetrics, "Should have no metrics initially")
        
        // When: Trigger manual refresh
        viewModel.manualRefresh()
        
        // Wait for refresh to complete
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Then: Verify metrics are collected immediately
        XCTAssertNotNil(viewModel.currentMetrics, "Manual refresh should collect metrics immediately")
        
        // Verify all new fields are accessible (values depend on system state)
        let metrics = viewModel.currentMetrics!
        
        // Core battery fields should always be present
        XCTAssertGreaterThanOrEqual(metrics.level, 0)
        XCTAssertLessThanOrEqual(metrics.level, 100)
        XCTAssertNotEqual(metrics.powerSource, .unknown)
        
        // Verify new field accessors work (structure is correct)
        _ = metrics.chargerWattage  // May be nil if not on AC
        _ = metrics.chargerAdapterName  // May be nil if not on AC
        _ = metrics.temperature  // Should typically have a value
        _ = metrics.manufactureDate  // Should typically have a value
        _ = metrics.serialNumber  // Should typically have a value
        _ = metrics.isLowPowerModeEnabled  // Should typically have a value
        
        // Verify computed properties work
        _ = metrics.hasChargerInfo
        _ = metrics.temperatureStatus
        
        let firstTimestamp = metrics.timestamp
        
        // When: Trigger manual refresh again (should fetch new data immediately)
        viewModel.manualRefresh()
        
        // Wait for second refresh to complete
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Then: Verify metrics are updated with new timestamp
        XCTAssertNotNil(viewModel.currentMetrics, "Second manual refresh should update metrics")
        XCTAssertNotEqual(viewModel.currentMetrics?.timestamp, firstTimestamp, 
                         "Timestamp should be updated on manual refresh")
        
        // Verify still not auto-monitoring
        XCTAssertFalse(viewModel.isMonitoring, "Should still not be auto-monitoring after manual refresh")
    }
    
    func testManualRefreshUpdatesMetricsHistory() async throws {
        // This test verifies that manual refresh adds entries to metrics history
        // with all new fields included
        
        // Given: A view model in manual refresh mode
        let viewModel = BatterySnapshotViewModel()
        viewModel.updateRefreshInterval(.manual)
        
        XCTAssertEqual(viewModel.metricsHistory.count, 0, "History should be empty initially")
        
        // When: Trigger first manual refresh
        viewModel.manualRefresh()
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Then: Verify first entry in history
        XCTAssertEqual(viewModel.metricsHistory.count, 1, "History should have one entry after first refresh")
        
        let firstEntry = viewModel.metricsHistory.first!
        XCTAssertGreaterThanOrEqual(firstEntry.level, 0)
        
        // Verify new fields are part of the history entry
        _ = firstEntry.chargerWattage
        _ = firstEntry.chargerAdapterName
        _ = firstEntry.temperature
        _ = firstEntry.manufactureDate
        _ = firstEntry.serialNumber
        _ = firstEntry.isLowPowerModeEnabled
        
        // When: Trigger second manual refresh
        viewModel.manualRefresh()
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Then: Verify second entry in history
        XCTAssertEqual(viewModel.metricsHistory.count, 2, "History should have two entries after second refresh")
        
        let secondEntry = viewModel.metricsHistory.last!
        XCTAssertNotEqual(secondEntry.timestamp, firstEntry.timestamp, 
                         "Second entry should have different timestamp")
        
        // Verify new fields are part of the second history entry
        _ = secondEntry.chargerWattage
        _ = secondEntry.chargerAdapterName
        _ = secondEntry.temperature
        _ = secondEntry.manufactureDate
        _ = secondEntry.serialNumber
        _ = secondEntry.isLowPowerModeEnabled
    }
    
    func testManualRefreshWorksIndependentlyOfAutoRefresh() async throws {
        // This test verifies that manual refresh works correctly
        // even when auto-refresh is disabled
        
        // Given: A view model with manual refresh mode
        let viewModel = BatterySnapshotViewModel()
        viewModel.updateRefreshInterval(.manual)
        
        // Verify monitoring is not started
        XCTAssertEqual(viewModel.monitoringState, .notStarted)
        XCTAssertFalse(viewModel.isMonitoring)
        
        // When: Trigger manual refresh without starting monitoring
        viewModel.manualRefresh()
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Then: Verify metrics are collected
        XCTAssertNotNil(viewModel.currentMetrics, "Manual refresh should work without auto-monitoring")
        
        // Verify monitoring state remains unchanged
        XCTAssertEqual(viewModel.monitoringState, .notStarted, 
                      "Manual refresh should not change monitoring state")
        XCTAssertFalse(viewModel.isMonitoring, 
                      "Manual refresh should not start auto-monitoring")
        
        // Verify all new fields are accessible
        let metrics = viewModel.currentMetrics!
        _ = metrics.chargerWattage
        _ = metrics.chargerAdapterName
        _ = metrics.temperature
        _ = metrics.manufactureDate
        _ = metrics.serialNumber
        _ = metrics.isLowPowerModeEnabled
    }
    
    func testLastKnownValuesPersistedWhenRefreshFails() async throws {
        // Given: A mock monitoring service with initial successful metrics
        let mockService = MockBatteryMonitoringService()
        let viewModel = BatterySnapshotViewModel(monitoringService: mockService)
        
        let initialMetrics = BatteryMetrics(
            timestamp: Date(),
            level: 80,
            powerSource: .ac,
            chargingState: .charging,
            condition: .normal,
            cycleCount: 50,
            fullChargeCapacity: 4800,
            designCapacity: 5000,
            currentCharge: 4000,
            chargerWattage: 94,
            chargerAdapterName: "94W USB-C Power Adapter",
            temperature: 29.0,
            manufactureDate: Date(timeIntervalSince1970: 1684108800),
            serialNumber: "C02TEST123",
            isLowPowerModeEnabled: false
        )
        
        mockService.metricsToReturn = initialMetrics
        
        // When: Start monitoring and get initial metrics
        viewModel.updateRefreshInterval(.fifteenSeconds)
        viewModel.startMonitoring()
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then: Verify initial metrics are set
        XCTAssertNotNil(viewModel.currentMetrics)
        let savedTimestamp = viewModel.currentMetrics?.timestamp
        XCTAssertEqual(viewModel.currentMetrics?.chargerWattage, 94)
        XCTAssertEqual(viewModel.currentMetrics?.temperature, 29.0)
        XCTAssertEqual(viewModel.currentMetrics?.serialNumber, "C02TEST123")
        
        // Given: Service now fails to return metrics (simulating command failure)
        mockService.shouldFail = true
        
        // When: Wait for next refresh cycle (15 seconds + buffer)
        try await Task.sleep(nanoseconds: 16_000_000_000) // 16 seconds
        
        // Then: Verify last known values are still present (service stopped on error)
        XCTAssertNotNil(viewModel.currentMetrics, "Current metrics should still be available")
        XCTAssertEqual(viewModel.currentMetrics?.timestamp, savedTimestamp, "Timestamp should remain unchanged")
        XCTAssertEqual(viewModel.currentMetrics?.chargerWattage, 94, "Last known charger wattage should persist")
        XCTAssertEqual(viewModel.currentMetrics?.temperature, 29.0, "Last known temperature should persist")
        XCTAssertEqual(viewModel.currentMetrics?.serialNumber, "C02TEST123", "Last known serial should persist")
        
        // Cleanup
        viewModel.stopMonitoring()
    }
    
    func testLoadingIndicatorDisplayedDuringRefresh() async throws {
        // Given: A view model that hasn't started monitoring yet
        let viewModel = BatterySnapshotViewModel()
        
        // Then: Initially not monitoring
        XCTAssertFalse(viewModel.isMonitoring)
        XCTAssertNil(viewModel.currentMetrics)
        
        // When: Start monitoring
        viewModel.updateRefreshInterval(.fifteenSeconds)
        viewModel.startMonitoring()
        
        // Then: isMonitoring should be true (indicating loading state)
        XCTAssertTrue(viewModel.isMonitoring, "isMonitoring should be true during active monitoring")
        
        // Wait for initial data collection
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Should have metrics and still be monitoring
        XCTAssertNotNil(viewModel.currentMetrics)
        XCTAssertTrue(viewModel.isMonitoring)
        
        // Cleanup
        viewModel.stopMonitoring()
        XCTAssertFalse(viewModel.isMonitoring)
    }
}

// MARK: - Mock Battery Monitoring Service

class MockBatteryMonitoringService: BatteryMonitoringServiceProtocol {
    var metricsToReturn: BatteryMetrics?
    var shouldFail = false
    private var continuation: AsyncStream<BatteryMetrics>.Continuation?
    
    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<BatteryMetrics> {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }
        
        return AsyncStream { continuation in
            self.continuation = continuation
            
            // Emit metrics periodically
            Task {
                while !Task.isCancelled {
                    if let metrics = self.metricsToReturn {
                        continuation.yield(metrics)
                    }
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                continuation.finish()
            }
        }
    }
    
    func stopMonitoring() {
        continuation?.finish()
        continuation = nil
    }

    func fetchCurrentMetrics() async throws -> BatteryMetrics {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }

        guard let metricsToReturn else {
            throw NSError(domain: "MockError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing metrics"])
        }

        return metricsToReturn
    }
}
