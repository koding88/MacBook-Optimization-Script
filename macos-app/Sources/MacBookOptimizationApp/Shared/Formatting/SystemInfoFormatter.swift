import Foundation

struct DisplaySummary: Equatable {
    let primary: String
    let secondary: String
}

struct SystemInfoFormatter {
    let localizer: AppLocalizer

    func memorySummary(memoryBytes: UInt64) -> String {
        guard memoryBytes > 0 else { return localizer.text(.unavailable) }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = false
        formatter.includesCount = true
        return formatter.string(fromByteCount: Int64(memoryBytes))
    }

    func storageSummary(totalBytes: Int64, availableBytes: Int64) -> String {
        let totalGigabytes = decimalGigabytes(totalBytes)
        let usedGigabytes = decimalGigabytes(max(availableBytes, 0))
        let ofText = localizer.text(.commonOf)
        let usedText = localizer.text(.commonUsed)
        return "\(formattedGigabytes(usedGigabytes)) \(ofText) \(formattedGigabytes(totalGigabytes)) \(usedText)"
    }

    func displaySummary(name: String, resolution: String) -> DisplaySummary {
        DisplaySummary(
            primary: name,
            secondary: resolution
        )
    }

    private func decimalGigabytes(_ bytes: Int64) -> Double {
        Double(bytes) / 1_000_000_000
    }

    private func formattedGigabytes(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: localizer.language.rawValue)
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(number) GB"
    }
}
