import Foundation

struct MemoryMetrics: Equatable {
    enum PressureLevel: Equatable {
        case normal
        case elevated
        case critical
    }

    let timestamp: Date
    let totalBytes: Int64
    let appBytes: Int64
    let wiredBytes: Int64
    let compressedBytes: Int64
    let cachedBytes: Int64
    let freeBytes: Int64
    let swapUsedBytes: Int64
    let pageSizeBytes: Int64

    var usedBytes: Int64 {
        min(totalBytes, max(0, appBytes + wiredBytes + compressedBytes))
    }

    var availableBytes: Int64 {
        max(0, cachedBytes + freeBytes)
    }

    var freeRatio: Double {
        ratio(for: freeBytes)
    }

    var cachedRatio: Double {
        ratio(for: cachedBytes)
    }

    var usedRatio: Double {
        ratio(for: usedBytes)
    }

    var compressedRatio: Double {
        ratio(for: compressedBytes)
    }

    var swapRatio: Double {
        ratio(for: swapUsedBytes)
    }

    var pressureScore: Double {
        let reclaimableRatio = min((Double(availableBytes) / safeTotalBytes), 1)
        let baseScore = usedRatio * 0.58
            + compressedRatio * 0.34
            + min(swapRatio * 1.4, 0.45)
            - reclaimableRatio * 0.16

        return min(max(baseScore, 0.08), 1)
    }

    var pressureLevel: PressureLevel {
        if swapUsedBytes > 512 * 1_024 * 1_024 || pressureScore >= 0.78 {
            return .critical
        }
        if pressureScore >= 0.55 || compressedRatio >= 0.16 {
            return .elevated
        }
        return .normal
    }

    private var safeTotalBytes: Double {
        max(Double(totalBytes), 1)
    }

    private func ratio(for bytes: Int64) -> Double {
        min(max(Double(bytes) / safeTotalBytes, 0), 1)
    }

    static func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: bytes)
    }
}

enum MemorySnapshotCommand {
    static let requests: [CommandRequest] = [
        CommandRequest(
            command: "printf 'Total RAM Bytes: '; sysctl -n hw.memsize",
            requiresAdministrator: false
        ),
        CommandRequest(
            command: "printf '\\nSwap Usage:\\n'; sysctl vm.swapusage",
            requiresAdministrator: false
        ),
        CommandRequest(
            command: "printf '\\nVM Stat:\\n'; vm_stat",
            requiresAdministrator: false
        )
    ]

    static var combinedCommand: String {
        requests.map(\.command).joined(separator: "\n")
    }
}

struct MemoryMetricsParser {
    static func parse(_ output: String) -> MemoryMetrics? {
        let lines = output.components(separatedBy: .newlines)
        guard let totalBytes = parseRawBytes(after: "Total RAM Bytes:", in: lines),
              let pageSizeBytes = parsePageSize(in: lines) else {
            return nil
        }

        let freePages = parsePageCount(after: "Pages free:", in: lines) ?? 0
        let speculativePages = parsePageCount(after: "Pages speculative:", in: lines) ?? 0
        let wiredPages = parsePageCount(after: "Pages wired down:", in: lines) ?? 0
        let purgeablePages = parsePageCount(after: "Pages purgeable:", in: lines) ?? 0
        let fileBackedPages = parsePageCount(after: "File-backed pages:", in: lines) ?? 0
        let anonymousPages = parsePageCount(after: "Anonymous pages:", in: lines) ?? 0
        let compressedPages = parsePageCount(after: "Pages occupied by compressor:", in: lines) ?? 0
        let swapUsedBytes = parseSwapUsedBytes(in: lines) ?? 0

        let pageSize = Int64(pageSizeBytes)
        let cachedPages = fileBackedPages + speculativePages + purgeablePages

        return MemoryMetrics(
            timestamp: .now,
            totalBytes: Int64(totalBytes),
            appBytes: anonymousPages * pageSize,
            wiredBytes: wiredPages * pageSize,
            compressedBytes: compressedPages * pageSize,
            cachedBytes: cachedPages * pageSize,
            freeBytes: freePages * pageSize,
            swapUsedBytes: swapUsedBytes,
            pageSizeBytes: pageSize
        )
    }

    private static func parseRawBytes(after prefix: String, in lines: [String]) -> Int64? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return Int64(line.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func parsePageSize(in lines: [String]) -> Int64? {
        guard let line = lines.first(where: { $0.contains("page size of") }) else { return nil }
        return firstInteger(in: line)
    }

    private static func parsePageCount(after prefix: String, in lines: [String]) -> Int64? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return firstInteger(in: line.replacingOccurrences(of: prefix, with: ""))
    }

    static func parseSwapUsedBytes(in lines: [String]) -> Int64? {
        guard let line = lines.first(where: { $0.contains("vm.swapusage:") }) else { return nil }
        let pattern = #"used\s*=\s*([0-9.]+)([BKMGTP])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let lineRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: lineRange),
              let valueRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line),
              let value = Double(line[valueRange]) else {
            return nil
        }

        let unit = String(line[unitRange]).uppercased()
        let multiplier: Double

        switch unit {
        case "B": multiplier = 1
        case "K": multiplier = 1_024
        case "M": multiplier = 1_024 * 1_024
        case "G": multiplier = 1_024 * 1_024 * 1_024
        case "T": multiplier = 1_024 * 1_024 * 1_024 * 1_024
        case "P": multiplier = 1_024 * 1_024 * 1_024 * 1_024 * 1_024
        default: multiplier = 1
        }

        return Int64(value * multiplier)
    }

    private static func firstInteger(in string: String) -> Int64? {
        let digits = string
            .replacingOccurrences(of: ",", with: "")
            .split(whereSeparator: { !$0.isNumber })
            .first

        guard let digits else { return nil }
        return Int64(digits)
    }
}
