import Foundation
import IOKit.ps
import AppKit

final class SystemInfoProvider: SystemInfoProviding {
    private let snapshotProvider = SystemSnapshotProvider()
    private let formatter = SystemInfoFormatter(localizer: AppLocalizer(language: .english))

    func machineSummary() async -> MachineSummary {
        let processInfo = ProcessInfo.processInfo
        let systemVersion = processInfo.operatingSystemVersionString
        let storageSnapshot = await snapshotProvider.storageSnapshot()
        let displaySummary = primaryDisplaySummary()
        let cpuCount = ProcessInfo.processInfo.processorCount

        return MachineSummary(
            modelName: sysctlString("hw.model") ?? "Mac",
            marketingModel: sysctlString("hw.model") ?? "Mac",
            chip: sysctlString("machdep.cpu.brand_string") ?? appleSiliconChipName(),
            coreDescription: "\(cpuCount)-core CPU",
            memoryBytes: processInfo.physicalMemory,
            storageTotalBytes: storageSnapshot.totalBytes,
            storageAvailableBytes: storageSnapshot.availableBytes,
            displayName: displaySummary.primary,
            displayResolution: displaySummary.secondary,
            storageSnapshot: storageSnapshot,
            systemVersion: systemVersion,
            battery: batterySummary(),
            serialNumber: nil
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
            return "Apple Silicon"
        }
        return "Unknown"
    }

    private func primaryDisplaySummary() -> DisplaySummary {
        guard let screen = NSScreen.screens.first else {
            return formatter.displaySummary(name: "Built-in Display", resolution: "Unavailable")
        }

        let description = screen.localizedName.isEmpty ? "Built-in Display" : screen.localizedName
        let size = screen.deviceDescription[NSDeviceDescriptionKey("NSDeviceSize")] as? NSSize ?? screen.frame.size
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let resolution = width > 0 && height > 0 ? "\(width) × \(height)" : "Unavailable"

        return formatter.displaySummary(name: description, resolution: resolution)
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
