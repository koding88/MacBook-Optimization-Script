import Darwin
import Foundation

private let ctlVM = Int32(2)
private let vmSwapUsage = Int32(5)

protocol MemorySnapshotCollecting {
    func collectSnapshot() throws -> MemoryMetrics
}

struct MemorySwapUsage: Equatable {
    let totalBytes: UInt64
    let availableBytes: UInt64
    let usedBytes: UInt64
    let pageSizeBytes: UInt32
    let isEncrypted: Bool
}

struct MemoryVMStatistics: Equatable {
    let freePages: Int64
    let speculativePages: Int64
    let wiredPages: Int64
    let purgeablePages: Int64
    let fileBackedPages: Int64
    let anonymousPages: Int64
    let compressedPages: Int64
    let pageSizeBytes: Int64
}

struct NativeMemorySnapshotCollector: MemorySnapshotCollecting {
    private let totalMemoryProvider: () throws -> Int64
    private let vmStatisticsProvider: () throws -> MemoryVMStatistics
    private let swapUsageProvider: () throws -> Int64?

    init(
        totalMemoryProvider: @escaping () throws -> Int64 = Self.defaultTotalMemoryBytes,
        vmStatisticsProvider: @escaping () throws -> MemoryVMStatistics = Self.defaultVMStatistics,
        swapUsageProvider: @escaping () throws -> Int64? = Self.defaultSwapUsedBytes
    ) {
        self.totalMemoryProvider = totalMemoryProvider
        self.vmStatisticsProvider = vmStatisticsProvider
        self.swapUsageProvider = swapUsageProvider
    }

    func collectSnapshot() throws -> MemoryMetrics {
        let totalBytes = try totalMemoryProvider()
        let vmStats = try vmStatisticsProvider()
        let pageSize = vmStats.pageSizeBytes
        let cachedPages = vmStats.fileBackedPages + vmStats.speculativePages + vmStats.purgeablePages

        return MemoryMetrics(
            timestamp: .now,
            totalBytes: totalBytes,
            appBytes: vmStats.anonymousPages * pageSize,
            wiredBytes: vmStats.wiredPages * pageSize,
            compressedBytes: vmStats.compressedPages * pageSize,
            cachedBytes: cachedPages * pageSize,
            freeBytes: vmStats.freePages * pageSize,
            swapUsedBytes: try swapUsageProvider() ?? 0,
            pageSizeBytes: pageSize
        )
    }

    private static func defaultTotalMemoryBytes() throws -> Int64 {
        Int64(ProcessInfo.processInfo.physicalMemory)
    }

    private static func defaultVMStatistics() throws -> MemoryVMStatistics {
        var pageSize: vm_size_t = 0
        let pageSizeStatus = host_page_size(mach_host_self(), &pageSize)
        guard pageSizeStatus == KERN_SUCCESS else {
            throw MemoryMonitoringError.nativeCollectionFailed("Unable to read host page size.")
        }

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: vmStats) / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &vmStats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard status == KERN_SUCCESS else {
            throw MemoryMonitoringError.nativeCollectionFailed("Unable to read VM statistics.")
        }

        return MemoryVMStatistics(
            freePages: Int64(vmStats.free_count),
            speculativePages: Int64(vmStats.speculative_count),
            wiredPages: Int64(vmStats.wire_count),
            purgeablePages: Int64(vmStats.purgeable_count),
            fileBackedPages: Int64(vmStats.external_page_count),
            anonymousPages: Int64(vmStats.internal_page_count),
            compressedPages: Int64(vmStats.compressor_page_count),
            pageSizeBytes: Int64(pageSize)
        )
    }

    private static func defaultSwapUsedBytes() throws -> Int64? {
        try parseSwapUsage(readSwapUsage())
    }

    static func parseSwapUsage(_ usage: MemorySwapUsage?) throws -> Int64? {
        guard let usage else { return nil }
        return Int64(clamping: usage.usedBytes)
    }

    private static func readSwapUsage() throws -> MemorySwapUsage? {
        var mib = [ctlVM, vmSwapUsage]
        var rawUsage = xsw_usage()
        var size = MemoryLayout.size(ofValue: rawUsage)
        let status = withUnsafeMutablePointer(to: &rawUsage) { usagePointer in
            sysctl(&mib, u_int(mib.count), usagePointer, &size, nil, 0)
        }

        guard status == 0 else {
            throw MemoryMonitoringError.nativeCollectionFailed("Unable to read swap usage.")
        }

        return MemorySwapUsage(
            totalBytes: rawUsage.xsu_total,
            availableBytes: rawUsage.xsu_avail,
            usedBytes: rawUsage.xsu_used,
            pageSizeBytes: rawUsage.xsu_pagesize,
            isEncrypted: rawUsage.xsu_encrypted != 0
        )
    }
}
