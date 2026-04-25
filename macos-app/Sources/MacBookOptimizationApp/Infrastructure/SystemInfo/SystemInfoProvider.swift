import Foundation
import IOKit.ps
import AppKit
import CoreGraphics

final class SystemInfoProvider: SystemInfoProviding {
    private let snapshotProvider = SystemSnapshotProvider()
    private let localizer: AppLocalizer
    private let systemProfilerReader = SystemProfilerJSONReader()
    private var formatter: SystemInfoFormatter {
        SystemInfoFormatter(localizer: localizer)
    }

    init(localizer: AppLocalizer = AppLocalizer(language: .english)) {
        self.localizer = localizer
    }

    struct HardwareSnapshot: Equatable {
        let marketingModel: String
        let modelIdentifier: String
        let chipName: String?
        let serialNumber: String?
    }

    private struct DisplaySnapshot {
        let gpuDescription: String?
        let displayName: String
        let displayResolution: String
    }

    func machineSummary() async -> MachineSummary {
        let processInfo = ProcessInfo.processInfo
        let systemVersion = processInfo.operatingSystemVersionString
        let storageSnapshot = await snapshotProvider.storageSnapshot()
        let hardwareSnapshot = primaryHardwareSnapshot()
        let displaySnapshot = primaryDisplaySnapshot()
        let cpuCount = ProcessInfo.processInfo.processorCount
        let modelIdentifier = hardwareSnapshot?.modelIdentifier ?? sysctlString("hw.model") ?? localizer.text(.systemUnknownMac)
        let marketingModel = hardwareSnapshot?.marketingModel ?? modelIdentifier
        let chipName = hardwareSnapshot?.chipName ?? sysctlString("machdep.cpu.brand_string") ?? appleSiliconChipName()

        return MachineSummary(
            modelName: modelIdentifier,
            marketingModel: marketingModel,
            chip: chipName,
            coreDescription: "\(cpuCount)-core CPU",
            gpuDescription: displaySnapshot.gpuDescription,
            memoryBytes: processInfo.physicalMemory,
            storageTotalBytes: storageSnapshot.totalBytes,
            storageAvailableBytes: storageSnapshot.availableBytes,
            displayName: displaySnapshot.displayName,
            displayResolution: displaySnapshot.displayResolution,
            storageSnapshot: storageSnapshot,
            systemVersion: systemVersion,
            battery: batterySummary(),
            serialNumber: hardwareSnapshot?.serialNumber
        )
    }

    private func sysctlString(_ key: String) -> String? {
        var size = 0
        sysctlbyname(key, nil, &size, nil, 0)
        guard size > 0 else { return nil }

        var value = [CChar](repeating: 0, count: size)
        let result = sysctlbyname(key, &value, &size, nil, 0)
        guard result == 0 else { return nil }
        return String(cString: value)
    }

    private func appleSiliconChipName() -> String {
        if let machine = sysctlString("hw.optional.arm64"), machine == "1" {
            return localizer.text(.dashboardAppleSilicon)
        }
        return localizer.text(.unavailable)
    }

    private func primaryDisplaySnapshot() -> DisplaySnapshot {
        if let snapshot = primaryDisplaySnapshotFromSystemProfiler() {
            return snapshot
        }

        guard let screen = NSScreen.screens.first else {
            return DisplaySnapshot(
                gpuDescription: nil,
                displayName: localizer.text(.dashboardBuiltInDisplay),
                displayResolution: localizer.text(.unavailable)
            )
        }

        let description = screen.localizedName.isEmpty ? localizer.text(.dashboardBuiltInDisplay) : screen.localizedName
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let mode = displayID.flatMap(CGDisplayCopyDisplayMode)
        let width = mode.map(\.pixelWidth) ?? Int(screen.frame.width.rounded())
        let height = mode.map(\.pixelHeight) ?? Int(screen.frame.height.rounded())
        let resolution = width > 0 && height > 0 ? "\(width) × \(height)" : localizer.text(.unavailable)

        return DisplaySnapshot(gpuDescription: nil, displayName: description, displayResolution: resolution)
    }

    private func primaryHardwareSnapshot() -> HardwareSnapshot? {
        guard
            let hardwareEntries = systemProfilerEntries(for: "SPHardwareDataType"),
            let hardwareEntry = hardwareEntries.first
        else {
            return nil
        }

        return Self.hardwareSnapshot(from: hardwareEntry)
    }

    private func primaryDisplaySnapshotFromSystemProfiler() -> DisplaySnapshot? {
        guard
            let displays = systemProfilerEntries(for: "SPDisplaysDataType"),
            let gpuEntry = displays.first
        else {
            return nil
        }

        let gpuDescription = (gpuEntry["sppci_cores"] as? String).map { "\($0)-core GPU" }
        let displayEntry = (gpuEntry["spdisplays_ndrvs"] as? [[String: Any]])?.first
        let displayName = normalizedDisplayName(from: displayEntry) ?? localizer.text(.dashboardBuiltInDisplay)
        let resolution = normalizedDisplayResolution(from: displayEntry) ?? localizer.text(.unavailable)

        return DisplaySnapshot(
            gpuDescription: gpuDescription,
            displayName: displayName,
            displayResolution: resolution
        )
    }

    private func systemProfilerEntries(for dataType: String) -> [[String: Any]]? {
        systemProfilerReader.entries(for: dataType)
    }

    static func hardwareSnapshot(from entry: [String: Any]) -> HardwareSnapshot? {
        let marketingModel = (entry["machine_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelIdentifier = (entry["machine_model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let marketingModel,
            !marketingModel.isEmpty,
            let modelIdentifier,
            !modelIdentifier.isEmpty
        else {
            return nil
        }

        let chipName = (entry["chip_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let serialNumber = (entry["serial_number"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return HardwareSnapshot(
            marketingModel: marketingModel,
            modelIdentifier: modelIdentifier,
            chipName: chipName?.isEmpty == true ? nil : chipName,
            serialNumber: serialNumber?.isEmpty == true ? nil : serialNumber
        )
    }

    private func normalizedDisplayResolution(from entry: [String: Any]?) -> String? {
        guard let entry else { return nil }

        if let pixelResolution = entry["spdisplays_pixelresolution"] as? String,
           let normalized = extractResolution(from: pixelResolution) {
            let refresh = extractRefreshRate(from: entry["_spdisplays_resolution"] as? String)
            return [normalized, refresh].compactMap { $0 }.joined(separator: " • ")
        }

        if let resolution = entry["_spdisplays_pixels"] as? String {
            let refresh = extractRefreshRate(from: entry["_spdisplays_resolution"] as? String)
            let normalized = resolution.replacingOccurrences(of: " x ", with: " × ")
            return [normalized, refresh].compactMap { $0 }.joined(separator: " • ")
        }

        return nil
    }

    private func extractResolution(from value: String) -> String? {
        let numbers = value.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        guard numbers.count >= 2 else { return nil }
        return "\(numbers[0]) × \(numbers[1])"
    }

    private func extractRefreshRate(from value: String?) -> String? {
        guard let value else { return nil }
        let numbers = value.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).filter { !$0.isEmpty }
        guard let raw = numbers.last, let hz = Double(raw) else { return nil }
        return hz.rounded(.towardZero) == hz ? "\(Int(hz))Hz" : "\(hz)Hz"
    }

    private func normalizedDisplayName(from entry: [String: Any]?) -> String? {
        guard let entry else { return nil }

        if let type = entry["spdisplays_display_type"] as? String {
            switch type {
            case "spdisplays_built-in-liquid-retina-xdr":
                return "Built-in Liquid Retina XDR Display"
            case "spdisplays_built-in-retina":
                return "Built-in Retina Display"
            default:
                break
            }
        }

        return entry["_name"] as? String
    }

    private func batterySummary() -> BatterySummary? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }

        let current = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let max = description[kIOPSMaxCapacityKey as String] as? Int ?? 0
        let percentage = max > 0 ? Int((Double(current) / Double(max)) * 100) : 0

        return BatterySummary(
            chargePercent: "\(percentage)%",
            condition: description[kIOPSBatteryHealthKey as String] as? String,
            cycleCount: (description["Cycle Count"] as? Int).map(String.init),
            powerSource: description[kIOPSPowerSourceStateKey as String] as? String
        )
    }
}
