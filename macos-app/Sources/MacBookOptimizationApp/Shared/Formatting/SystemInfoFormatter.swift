import Foundation

struct DisplaySummary: Equatable {
    let primary: String
    let secondary: String
}

struct SystemInfoFormatter {
    let localizer: AppLocalizer

    func memorySummary(memoryBytes: UInt64) -> String {
        guard memoryBytes > 0 else { return localizer.text(.unavailable) }
        let gigabytes = Int((Double(memoryBytes) / 1_000_000_000).rounded())
        return "\(gigabytes) GB"
    }

    func storageSummary(totalBytes: Int64, availableBytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true

        let total = formatter.string(fromByteCount: totalBytes)
        let available = formatter.string(fromByteCount: availableBytes)
        let suffix = localizer.string("system.storage.availableSuffix")

        return "\(total) • \(available) \(suffix)"
    }

    func displaySummary(name: String, resolution: String) -> DisplaySummary {
        DisplaySummary(
            primary: name,
            secondary: resolution
        )
    }
}
