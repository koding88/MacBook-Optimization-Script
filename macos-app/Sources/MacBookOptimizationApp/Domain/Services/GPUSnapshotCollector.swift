import Foundation

#if canImport(Metal)
import Metal
#endif

struct GPUSnapshot: Equatable {
    struct ThreadgroupSize: Equatable {
        let width: Int
        let height: Int
        let depth: Int
    }

    struct Device: Equatable {
        enum Source: Equatable {
            case systemProfiler
            case metal
            case merged
        }

        let name: String
        let metalSupport: String?
        let displayCount: Int
        let source: Source
        let systemProfilerReportedName: String?
        let metalReportedName: String?
        let isLowPower: Bool?
        let isRemovable: Bool?
        let hasUnifiedMemory: Bool?
        let recommendedMaxWorkingSetSizeBytes: UInt64?
        let maxThreadsPerThreadgroup: ThreadgroupSize?
        let supportsFeatureSetFallback: Bool?
        let supportedFamilies: [String]
    }

    struct Display: Equatable {
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

    struct LiveTelemetry: Equatable {
        let isPubliclyUnavailable: Bool
        let explanation: String
    }

    let devices: [Device]
    let displays: [Display]
    let liveTelemetry: LiveTelemetry
}

struct GPUMetalDeviceSnapshot: Equatable {
    let registryID: UInt64
    let name: String
    let isLowPower: Bool
    let isRemovable: Bool
    let hasUnifiedMemory: Bool
    let recommendedMaxWorkingSetSize: UInt64
    let maxThreadsPerThreadgroup: GPUSnapshot.ThreadgroupSize
    let supportsFeatureSetFallback: Bool
    let supportedFamilies: [String]
}

struct GPUSnapshotCollector {
    typealias SystemProfilerEntriesProvider = (String) -> [[String: Any]]?
    typealias MetalDevicesProvider = () -> [GPUMetalDeviceSnapshot]
    typealias IORegistryPropertiesProvider = () -> [[String: Any]]

    private let systemProfilerEntriesProvider: SystemProfilerEntriesProvider
    private let metalDevicesProvider: MetalDevicesProvider
    private let ioRegistryPropertiesProvider: IORegistryPropertiesProvider

    init(
        systemProfilerEntriesProvider: @escaping SystemProfilerEntriesProvider = { SystemProfilerJSONReader().entries(for: $0) },
        metalDevicesProvider: @escaping MetalDevicesProvider = Self.defaultMetalDevices,
        ioRegistryPropertiesProvider: @escaping IORegistryPropertiesProvider = { [] }
    ) {
        self.systemProfilerEntriesProvider = systemProfilerEntriesProvider
        self.metalDevicesProvider = metalDevicesProvider
        self.ioRegistryPropertiesProvider = ioRegistryPropertiesProvider
    }

    func collectSnapshot() throws -> GPUSnapshot {
        let profilerEntries = systemProfilerEntriesProvider("SPDisplaysDataType") ?? []
        let profilerSnapshot = Self.systemProfilerSnapshot(from: profilerEntries)
        let metalDevices = metalDevicesProvider()
        _ = ioRegistryPropertiesProvider()

        let mergedDevices = mergeDevices(systemProfilerDevices: profilerSnapshot.devices, metalDevices: metalDevices)
        let displays = profilerSnapshot.displays

        return GPUSnapshot(
            devices: mergedDevices,
            displays: displays,
            liveTelemetry: GPUSnapshot.LiveTelemetry(
                isPubliclyUnavailable: true,
                explanation: "Public macOS APIs expose static GPU capabilities, but not stable system-wide live GPU utilization, frequency, memory use, or power draw."
            )
        )
    }

    static func systemProfilerSnapshot(from entries: [[String: Any]]) -> GPUSnapshot {
        let devices = entries.map { entry in
            GPUSnapshot.Device(
                name: normalizedString(entry["sppci_model"]) ?? normalizedString(entry["spdisplays_vendor"]) ?? "Unknown GPU",
                metalSupport: normalizedMetalSupport(from: entry),
                displayCount: (entry["spdisplays_ndrvs"] as? [[String: Any]])?.count ?? 0,
                source: .systemProfiler,
                systemProfilerReportedName: normalizedString(entry["sppci_model"]) ?? normalizedString(entry["spdisplays_vendor"]),
                metalReportedName: nil,
                isLowPower: nil,
                isRemovable: nil,
                hasUnifiedMemory: nil,
                recommendedMaxWorkingSetSizeBytes: nil,
                maxThreadsPerThreadgroup: nil,
                supportsFeatureSetFallback: nil,
                supportedFamilies: []
            )
        }

        let displays = entries
            .flatMap { ($0["spdisplays_ndrvs"] as? [[String: Any]]) ?? [] }
            .map { entry in
                GPUSnapshot.Display(
                    name: normalizedString(entry["_name"]) ?? "Display",
                    resolution: normalizedResolution(from: entry),
                    refreshRate: normalizedRefreshRate(from: entry),
                    scaleDescription: normalizedScaleDescription(from: entry),
                    colorDepth: normalizedString(entry["spdisplays_depth"]),
                    supportsHDR: hdrSupport(from: entry),
                    supportsProMotion: proMotionSupport(from: entry),
                    isOnline: flagValue(entry["spdisplays_online"]),
                    isMain: flagValue(entry["spdisplays_main"])
                )
            }

        return GPUSnapshot(
            devices: devices,
            displays: displays,
            liveTelemetry: GPUSnapshot.LiveTelemetry(
                isPubliclyUnavailable: true,
                explanation: "Public macOS APIs do not provide stable system-wide live GPU telemetry."
            )
        )
    }

    private func mergeDevices(
        systemProfilerDevices: [GPUSnapshot.Device],
        metalDevices: [GPUMetalDeviceSnapshot]
    ) -> [GPUSnapshot.Device] {
        if systemProfilerDevices.isEmpty {
            return metalDevices.map {
                GPUSnapshot.Device(
                    name: $0.name,
                    metalSupport: nil,
                    displayCount: 0,
                    source: .metal,
                    systemProfilerReportedName: nil,
                    metalReportedName: $0.name,
                    isLowPower: $0.isLowPower,
                    isRemovable: $0.isRemovable,
                    hasUnifiedMemory: $0.hasUnifiedMemory,
                    recommendedMaxWorkingSetSizeBytes: $0.recommendedMaxWorkingSetSize,
                    maxThreadsPerThreadgroup: $0.maxThreadsPerThreadgroup,
                    supportsFeatureSetFallback: $0.supportsFeatureSetFallback,
                    supportedFamilies: $0.supportedFamilies
                )
            }
        }

        return systemProfilerDevices.map { device in
            guard let metal = metalDevices.first(where: { normalizedName($0.name) == normalizedName(device.name) }) else {
                return device
            }

            return GPUSnapshot.Device(
                name: device.name,
                metalSupport: device.metalSupport,
                displayCount: device.displayCount,
                source: .merged,
                systemProfilerReportedName: device.systemProfilerReportedName ?? device.name,
                metalReportedName: metal.name,
                isLowPower: metal.isLowPower,
                isRemovable: metal.isRemovable,
                hasUnifiedMemory: metal.hasUnifiedMemory,
                recommendedMaxWorkingSetSizeBytes: metal.recommendedMaxWorkingSetSize,
                maxThreadsPerThreadgroup: metal.maxThreadsPerThreadgroup,
                supportsFeatureSetFallback: metal.supportsFeatureSetFallback,
                supportedFamilies: metal.supportedFamilies
            )
        }
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedResolution(from entry: [String: Any]) -> String? {
        if let value = normalizedString(entry["spdisplays_pixelresolution"]),
           let retinaResolution = parseResolutionToken(value) {
            return retinaResolution
        }
        if let value = normalizedString(entry["_spdisplays_pixels"]) {
            return normalizeResolutionText(value)
        }
        if let value = normalizedString(entry["spdisplays_pixelresolution"]) {
            return normalizeResolutionText(value)
        }
        return nil
    }

    private static func normalizedMetalSupport(from entry: [String: Any]) -> String? {
        if let value = normalizedString(entry["spdisplays_metal"]) {
            return value
        }

        guard let familySupport = normalizedString(entry["spdisplays_mtlgpufamilysupport"]) else {
            return nil
        }

        switch familySupport {
        case "spdisplays_metal3":
            return "Metal 3"
        case "spdisplays_metal2":
            return "Metal 2"
        case "spdisplays_metal":
            return "Metal"
        default:
            if familySupport.hasPrefix("spdisplays_metal"),
               let suffix = familySupport.split(separator: "l").last,
               suffix.allSatisfy(\.isNumber) {
                return "Metal \(suffix)"
            }
            return familySupport.replacingOccurrences(of: "spdisplays_", with: "").replacingOccurrences(of: "_", with: " ")
        }
    }

    private static func normalizedRefreshRate(from entry: [String: Any]) -> String? {
        let raw = normalizedString(entry["_spdisplays_resolution"])
        guard let raw else { return nil }
        guard let atIndex = raw.range(of: "@") else { return nil }
        let value = raw[atIndex.upperBound...].trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        return value.replacingOccurrences(of: ".00Hz", with: "Hz")
    }

    private static func normalizedScaleDescription(from entry: [String: Any]) -> String? {
        guard let raw = normalizedString(entry["_spdisplays_resolution"]) else { return nil }
        let parts = raw.components(separatedBy: "@")
        guard let first = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty else {
            return nil
        }
        return "\(normalizeResolutionText(first)) scaled"
    }

    private static func hdrSupport(from entry: [String: Any]) -> Bool? {
        if let displayType = normalizedString(entry["spdisplays_display_type"]),
           displayType.contains("xdr") {
            return true
        }
        return nil
    }

    private static func proMotionSupport(from entry: [String: Any]) -> Bool? {
        guard let refreshRate = normalizedRefreshRate(from: entry) else { return nil }
        return refreshRate.contains("120Hz")
    }

    private static func parseResolutionToken(_ value: String) -> String? {
        guard let match = value.range(of: #"([0-9]+)x([0-9]+)"#, options: .regularExpression) else {
            return nil
        }
        return normalizeResolutionText(String(value[match]))
    }

    private static func normalizeResolutionText(_ value: String) -> String {
        value
            .replacingOccurrences(of: " x ", with: " × ")
            .replacingOccurrences(of: "x", with: " × ")
    }

    private static func flagValue(_ value: Any?) -> Bool {
        guard let string = value as? String else { return false }
        return string == "spdisplays_yes" || string == "yes" || string == "1"
    }

    private func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func defaultMetalDevices() -> [GPUMetalDeviceSnapshot] {
        #if canImport(Metal)
        let devices: [MTLDevice]
        if #available(macOS 10.13, *) {
            devices = MTLCopyAllDevices()
        } else if let defaultDevice = MTLCreateSystemDefaultDevice() {
            devices = [defaultDevice]
        } else {
            devices = []
        }

        return devices.map { device in
            GPUMetalDeviceSnapshot(
                registryID: device.registryID,
                name: device.name,
                isLowPower: device.isLowPower,
                isRemovable: device.isRemovable,
                hasUnifiedMemory: device.hasUnifiedMemory,
                recommendedMaxWorkingSetSize: device.recommendedMaxWorkingSetSize,
                maxThreadsPerThreadgroup: .init(
                    width: device.maxThreadsPerThreadgroup.width,
                    height: device.maxThreadsPerThreadgroup.height,
                    depth: device.maxThreadsPerThreadgroup.depth
                ),
                supportsFeatureSetFallback: true,
                supportedFamilies: supportedFamilies(for: device)
            )
        }
        #else
        return []
        #endif
    }

    #if canImport(Metal)
    private static func supportedFamilies(for device: MTLDevice) -> [String] {
        var families: [String] = []

        if #available(macOS 13.0, *) {
            let checks: [(MTLGPUFamily, String)] = [
                (.apple1, "Apple1"), (.apple2, "Apple2"), (.apple3, "Apple3"), (.apple4, "Apple4"),
                (.apple5, "Apple5"), (.apple6, "Apple6"), (.apple7, "Apple7"), (.apple8, "Apple8"),
                (.mac2, "Mac2")
            ]
            for (family, label) in checks where device.supportsFamily(family) {
                families.append(label)
            }
        }

        return families
    }
    #endif
}
