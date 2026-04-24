import Foundation

struct GPUMetrics: Equatable {
    struct ProcessUsage: Equatable, Identifiable {
        let id: String
        let name: String
        let gpuMillisecondsPerSecond: Double
    }

    let timestamp: Date
    let powerMilliwatts: Int?
    let frequencyMHz: Int?
    let usagePercent: Double?
    let memoryBytes: UInt64?
    let processes: [ProcessUsage]
}

enum GPUMetricsParser {
    static func parse(_ output: String) -> GPUMetrics? {
        let lines = output.components(separatedBy: .newlines)

        let powerMilliwatts = parsePower(from: lines)
        let frequencyMHz = parseFrequency(from: lines)
        let processes = parseProcesses(from: lines)
        let usagePercent = parseUsage(from: lines)
            ?? (processes.isEmpty ? nil : min(100, processes.reduce(0) { $0 + $1.gpuMillisecondsPerSecond } / 10))

        guard powerMilliwatts != nil || frequencyMHz != nil || usagePercent != nil || !processes.isEmpty else {
            return nil
        }

        return GPUMetrics(
            timestamp: .now,
            powerMilliwatts: powerMilliwatts,
            frequencyMHz: frequencyMHz,
            usagePercent: usagePercent,
            memoryBytes: nil,
            processes: processes
        )
    }

    static func parse(plistData: Data) -> GPUMetrics? {
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) else {
            return nil
        }

        let powerMilliwatts = firstNumber(
            forKeys: ["gpu_power", "gpu_power_mw", "gpu_power_mw_avg"],
            in: plist
        ).map { Int($0.rounded()) }

        let frequencyMHz = firstNumber(
            forKeys: ["gpu_frequency_mhz", "gpu_freq_mhz", "gpu_frequency"],
            in: plist
        )
        .map(normalizedFrequencyMHz(from:))
        ?? nestedGPUFrequencyMHz(in: plist)

        let memoryBytes = firstNumber(
            forKeys: ["gpu_memory_bytes", "gpu_working_set_bytes", "gpu_mem_bytes"],
            in: plist
        ).map { UInt64(max($0, 0)) }

        let processes = processMetrics(in: plist)
        let usagePercent =
            gpuActiveResidencyPercent(in: plist)
            ?? (processes.isEmpty ? nil : min(100, processes.reduce(0) { $0 + $1.gpuMillisecondsPerSecond } / 10))

        guard powerMilliwatts != nil || frequencyMHz != nil || usagePercent != nil || memoryBytes != nil || !processes.isEmpty else {
            return nil
        }

        return GPUMetrics(
            timestamp: .now,
            powerMilliwatts: powerMilliwatts,
            frequencyMHz: frequencyMHz,
            usagePercent: usagePercent,
            memoryBytes: memoryBytes,
            processes: processes
        )
    }

    private static func parsePower(from lines: [String]) -> Int? {
        guard let line = lines.first(where: { $0.contains("GPU Power:") }) else { return nil }
        if let mw = extractNumber(before: "mW", in: line) {
            return Int(mw.rounded())
        }
        if let watts = extractNumber(before: "W", in: line) {
            return Int((watts * 1_000).rounded())
        }
        return nil
    }

    private static func parseFrequency(from lines: [String]) -> Int? {
        if let line = lines.first(where: { $0.contains("GPU Frequency:") }) {
            return extractNumber(before: "MHz", in: line).map { Int($0.rounded()) }
        }

        if let line = lines.first(where: { $0.contains("GPU HW active frequency:") }) {
            return extractNumber(before: "MHz", in: line).map { Int($0.rounded()) }
        }

        return nil
    }

    private static func parseUsage(from lines: [String]) -> Double? {
        if let line = lines.first(where: { $0.contains("GPU HW active residency:") }) {
            return extractNumber(before: "%", in: line)
        }

        return nil
    }

    private static func firstNumber(forKeys keys: [String], in value: Any) -> Double? {
        if let dictionary = value as? [String: Any] {
            for key in keys {
                if let number = numberValue(dictionary[key]) {
                    return number
                }
            }

            for nested in dictionary.values {
                if let number = firstNumber(forKeys: keys, in: nested) {
                    return number
                }
            }
        }

        if let array = value as? [Any] {
            for item in array {
                if let number = firstNumber(forKeys: keys, in: item) {
                    return number
                }
            }
        }

        return nil
    }

    private static func normalizedFrequencyMHz(from rawValue: Double) -> Int {
        if rawValue >= 1_000_000 {
            return Int((rawValue / 1_000_000).rounded())
        }

        if rawValue >= 10_000 {
            return Int((rawValue / 1_000).rounded())
        }

        return Int(rawValue.rounded())
    }

    private static func nestedGPUFrequencyMHz(in value: Any) -> Int? {
        if let dictionary = value as? [String: Any] {
            if let gpu = dictionary["gpu"] as? [String: Any],
               let frequency = numberValue(gpu["freq_hz"]) {
                return normalizedFrequencyMHz(from: frequency)
            }

            for nested in dictionary.values {
                if let frequency = nestedGPUFrequencyMHz(in: nested) {
                    return frequency
                }
            }
        }

        if let array = value as? [Any] {
            for item in array {
                if let frequency = nestedGPUFrequencyMHz(in: item) {
                    return frequency
                }
            }
        }

        return nil
    }

    private static func gpuActiveResidencyPercent(in value: Any) -> Double? {
        if let dictionary = value as? [String: Any] {
            if let gpu = dictionary["gpu"] as? [String: Any] {
                if let states = gpu["dvfm_states"] as? [[String: Any]] {
                    let usedRatio = states.reduce(0.0) { partial, state in
                        partial + (numberValue(state["used_ratio"]) ?? 0)
                    }
                    if usedRatio > 0 {
                        return min(100, usedRatio * 100)
                    }
                }

                if let idleRatio = numberValue(gpu["idle_ratio"]) {
                    return min(100, max(0, (1 - idleRatio) * 100))
                }
            }

            for nested in dictionary.values {
                if let usage = gpuActiveResidencyPercent(in: nested) {
                    return usage
                }
            }
        }

        if let array = value as? [Any] {
            for item in array {
                if let usage = gpuActiveResidencyPercent(in: item) {
                    return usage
                }
            }
        }

        return nil
    }

    private static func processMetrics(in value: Any) -> [GPUMetrics.ProcessUsage] {
        var results: [GPUMetrics.ProcessUsage] = []
        collectProcessMetrics(in: value, into: &results)
        return Array(Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) }).values)
            .sorted { $0.gpuMillisecondsPerSecond > $1.gpuMillisecondsPerSecond }
    }

    private static func collectProcessMetrics(in value: Any, into results: inout [GPUMetrics.ProcessUsage]) {
        if let dictionary = value as? [String: Any] {
            if let name = stringValue(dictionary["name"]) ?? stringValue(dictionary["process_name"]),
               let gpuMS = numberValue(dictionary["gpu_ms_s"])
                    ?? numberValue(dictionary["gpu_ms_per_s"])
                    ?? numberValue(dictionary["gpu_time_ms_s"]) {
                results.append(
                    GPUMetrics.ProcessUsage(
                        id: name,
                        name: name,
                        gpuMillisecondsPerSecond: gpuMS
                    )
                )
            }

            for nested in dictionary.values {
                collectProcessMetrics(in: nested, into: &results)
            }
        }

        if let array = value as? [Any] {
            for item in array {
                collectProcessMetrics(in: item, into: &results)
            }
        }
    }

    private static func parseProcesses(from lines: [String]) -> [GPUMetrics.ProcessUsage] {
        guard let headerIndex = lines.firstIndex(where: { $0.contains("GPU ms/s") }) else { return [] }
        let rowRegex = try? NSRegularExpression(pattern: #"^\s*(.+?)\s+\d+\s+.*?([0-9]+(?:\.[0-9]+)?)\s*$"#)

        return lines[(headerIndex + 1)...].compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("***") else { return nil }

            guard let rowRegex else { return nil }
            let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = rowRegex.firstMatch(in: trimmed, range: nsRange),
                  let nameRange = Range(match.range(at: 1), in: trimmed),
                  let gpuRange = Range(match.range(at: 2), in: trimmed),
                  let gpuMilliseconds = Double(trimmed[gpuRange]) else {
                return nil
            }

            let finalName = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)

            return GPUMetrics.ProcessUsage(
                id: finalName,
                name: finalName,
                gpuMillisecondsPerSecond: gpuMilliseconds
            )
        }
    }

    private static func extractNumber(before suffix: String, in line: String) -> Double? {
        guard let range = line.range(of: #"[0-9]+(?:\.[0-9]+)?(?=\s*\#(suffix))"#, options: .regularExpression) else {
            return nil
        }
        return Double(line[range])
    }

    private static func numberValue(_ value: Any?) -> Double? {
        switch value {
        case let value as NSNumber:
            return value.doubleValue
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
