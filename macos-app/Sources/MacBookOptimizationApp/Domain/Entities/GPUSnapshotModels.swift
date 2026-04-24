import CoreGraphics
import Foundation

struct GPUSnapshotMetrics: Equatable {
    static let defaultMetricsTitle = "GPU Metrics"

    struct DeviceSummary: Equatable, Identifiable {
        let id: String
        let name: String
        let metalSupport: String?
        let displayCount: Int
        let hasUnifiedMemory: Bool?
        let recommendedMaxWorkingSetSizeBytes: UInt64?
        let supportedFamilies: [String]
    }

    struct DisplaySummary: Equatable, Identifiable {
        let id: String
        let name: String
        let resolution: String?
        let refreshRate: String?
        let scaleDescription: String?
        let colorDepth: String?
        let supportsHDR: Bool?
        let supportsProMotion: Bool?
        let isOnline: Bool
        let isMain: Bool
    }

    struct GPUMetricsStatus: Equatable {
        let title: String
        let detail: String?
        let metrics: GPUMetrics?
    }

    let timestamp: Date
    let devices: [DeviceSummary]
    let displays: [DisplaySummary]
    let gpuMetrics: GPUMetricsStatus
}

@MainActor
protocol GPUSnapshotProviding {
    func collectSnapshot() throws -> GPUSnapshotMetrics
}

struct NativeGPUSnapshotProvider: GPUSnapshotProviding {
    private let collector: GPUSnapshotCollector

    init(collector: GPUSnapshotCollector = GPUSnapshotCollector()) {
        self.collector = collector
    }

    func collectSnapshot() throws -> GPUSnapshotMetrics {
        let snapshot = try collector.collectSnapshot()

        let devices = snapshot.devices.enumerated().map { index, device in
            GPUSnapshotMetrics.DeviceSummary(
                id: "\(index)-\(device.name)",
                name: device.name,
                metalSupport: device.metalSupport,
                displayCount: device.displayCount,
                hasUnifiedMemory: device.hasUnifiedMemory,
                recommendedMaxWorkingSetSizeBytes: device.recommendedMaxWorkingSetSizeBytes,
                supportedFamilies: device.supportedFamilies
            )
        }

        let displays = snapshot.displays.enumerated().map { index, display in
            GPUSnapshotMetrics.DisplaySummary(
                id: "\(index)-\(display.name)",
                name: display.name,
                resolution: display.resolution,
                refreshRate: display.refreshRate,
                scaleDescription: display.scaleDescription,
                colorDepth: display.colorDepth,
                supportsHDR: display.supportsHDR,
                supportsProMotion: display.supportsProMotion,
                isOnline: display.isOnline,
                isMain: display.isMain
            )
        }

        return GPUSnapshotMetrics(
            timestamp: .now,
            devices: devices,
            displays: displays,
            gpuMetrics: .init(
                title: GPUSnapshotMetrics.defaultMetricsTitle,
                detail: nil,
                metrics: nil
            )
        )
    }
}

enum GPUSnapshotFormatting {
    static func byteString(_ value: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(clamping: value))
    }
}
