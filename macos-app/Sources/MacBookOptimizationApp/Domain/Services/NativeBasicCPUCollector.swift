import Darwin
import Foundation

protocol BasicCPUSnapshotCollecting {
    func collectSnapshot() throws -> BasicCPUMetrics
}

struct BasicCPUMetrics: Equatable {
    let timestamp: Date
    let cpuName: String
    let totalCores: Int
    let overallUsage: Double
    let thermalState: CPUMetrics.ThermalPressure
}

struct NativeBasicCPUCollector: BasicCPUSnapshotCollecting {
    private let machineSummaryProvider: () async -> MachineSummary
    private let processorCountProvider: () -> Int
    private let overallUsageProvider: () throws -> Double
    private let thermalStateProvider: () -> ProcessInfo.ThermalState
    private let timestampProvider: () -> Date

    init(
        machineSummaryProvider: @escaping () async -> MachineSummary = { await SystemInfoProvider().machineSummary() },
        processorCountProvider: @escaping () -> Int = { ProcessInfo.processInfo.processorCount },
        overallUsageProvider: @escaping () throws -> Double = Self.defaultOverallUsage,
        thermalStateProvider: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
        timestampProvider: @escaping () -> Date = { .now }
    ) {
        self.machineSummaryProvider = machineSummaryProvider
        self.processorCountProvider = processorCountProvider
        self.overallUsageProvider = overallUsageProvider
        self.thermalStateProvider = thermalStateProvider
        self.timestampProvider = timestampProvider
    }

    func collectSnapshot() throws -> BasicCPUMetrics {
        let semaphore = DispatchSemaphore(value: 0)
        var summary: MachineSummary?

        Task {
            summary = await machineSummaryProvider()
            semaphore.signal()
        }
        semaphore.wait()

        guard let summary else {
            throw CPUMonitoringError.parsingFailed
        }

        let detectedCores = processorCountProvider()
        let totalCores = detectedCores > 0 ? detectedCores : Self.parseCoreCount(from: summary.coreDescription)

        return BasicCPUMetrics(
            timestamp: timestampProvider(),
            cpuName: summary.chipName,
            totalCores: max(totalCores, 0),
            overallUsage: try overallUsageProvider(),
            thermalState: Self.mapThermalState(thermalStateProvider())
        )
    }

    private static func defaultOverallUsage() throws -> Double {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let status = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard status == KERN_SUCCESS, let cpuInfo else {
            throw CPUMonitoringError.parsingFailed
        }

        defer {
            let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        let info = Array(UnsafeBufferPointer(start: cpuInfo, count: Int(cpuInfoCount)))
        let stateCount = Int(CPU_STATE_MAX)
        let cpuTotalTicks = stride(from: 0, to: info.count, by: stateCount).reduce(0) { partial, offset in
            partial
                + Int(info[offset + Int(CPU_STATE_USER)])
                + Int(info[offset + Int(CPU_STATE_SYSTEM)])
                + Int(info[offset + Int(CPU_STATE_NICE)])
                + Int(info[offset + Int(CPU_STATE_IDLE)])
        }
        let activeTicks = stride(from: 0, to: info.count, by: stateCount).reduce(0) { partial, offset in
            partial
                + Int(info[offset + Int(CPU_STATE_USER)])
                + Int(info[offset + Int(CPU_STATE_SYSTEM)])
                + Int(info[offset + Int(CPU_STATE_NICE)])
        }

        guard cpuTotalTicks > 0 else { return 0 }
        return (Double(activeTicks) / Double(cpuTotalTicks)) * 100
    }

    private static func mapThermalState(_ state: ProcessInfo.ThermalState) -> CPUMetrics.ThermalPressure {
        switch state {
        case .nominal:
            return .nominal
        case .fair:
            return .moderate
        case .serious:
            return .heavy
        case .critical:
            return .trapping
        @unknown default:
            return .moderate
        }
    }

    private static func parseCoreCount(from description: String?) -> Int {
        guard let description else { return 0 }
        let digits = description.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }
}
