import Foundation

final class CPUMonitoringService: CPUMonitoringServiceProtocol {
    private let advancedService: AdvancedCPUMonitoringService

    init(advancedService: AdvancedCPUMonitoringService = AdvancedCPUMonitoringService()) {
        self.advancedService = advancedService
    }

    func startMonitoring(interval: TimeInterval) async throws -> AsyncStream<CPUMetrics> {
        try await advancedService.startMonitoring(interval: interval)
    }

    func stopMonitoring() {
        advancedService.stopMonitoring()
    }

    static func monitoringShellCommand(
        outputFilePath: String,
        stopFilePath: String,
        sampleIntervalMilliseconds: Int,
        sampleDelimiter: String = "\n__MBO_SAMPLE_END__\n"
    ) -> String {
        AdvancedCPUMonitoringService.monitoringShellCommand(
            outputFilePath: outputFilePath,
            stopFilePath: stopFilePath,
            pidFilePath: "/tmp/mbo-powermetrics.pid",
            sampleIntervalMilliseconds: sampleIntervalMilliseconds
        )
    }
}
