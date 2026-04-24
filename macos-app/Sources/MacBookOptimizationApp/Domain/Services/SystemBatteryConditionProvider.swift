import Foundation

protocol SystemBatteryConditionProviding {
    func currentCondition() -> BatteryMetrics.BatteryCondition?
}

struct SystemBatteryConditionProvider: SystemBatteryConditionProviding {
    func currentCondition() -> BatteryMetrics.BatteryCondition? {
        guard let entries = SystemProfilerJSONReader().entries(for: "SPPowerDataType") else {
            return nil
        }

        return currentCondition(from: entries)
    }

    func currentCondition(from entries: [[String: Any]]) -> BatteryMetrics.BatteryCondition? {
        guard
            let powerEntry = entries.first(where: {
                ($0["_name"] as? String) == "spbattery_information"
            }) ?? entries.first,
            let batteryHealth = powerEntry["sppower_battery_health_info"] as? [String: Any]
        else {
            return nil
        }

        if let condition = normalizedString(batteryHealth["sppower_battery_condition"]) {
            return mapCondition(condition)
        }

        if let health = normalizedString(batteryHealth["sppower_battery_health"]) {
            return mapCondition(health)
        }

        return nil
    }

    private func mapCondition(_ condition: String) -> BatteryMetrics.BatteryCondition {
        switch condition.lowercased() {
        case "normal", "good":
            return .normal
        case "replace soon":
            return .replaceSoon
        case "replace now":
            return .replaceNow
        case "service recommended", "service battery":
            return .serviceBattery
        default:
            return .unknown
        }
    }

    private func normalizedString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct SystemProfilerJSONReader {
    func entries(for dataType: String) -> [[String: Any]]? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = [dataType, "-json"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        guard task.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = json[dataType] as? [[String: Any]]
        else {
            return nil
        }

        return entries
    }
}
