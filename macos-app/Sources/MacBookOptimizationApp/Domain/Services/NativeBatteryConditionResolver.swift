import Foundation

struct NativeBatteryConditionResolver {
    func resolve(
        iopsCondition: String?,
        iopsHealth: String?,
        cycleCount: Int?,
        designCycleCount: Int?,
        fullChargeCapacity: Int?,
        designCapacity: Int?,
        batteryHealthMetric: Int?
    ) -> BatteryMetrics.BatteryCondition {
        if let explicitCondition = mapDirectCondition(iopsCondition) {
            return explicitCondition
        }

        let normalizedHealth = normalize(iopsHealth)
        switch normalizedHealth {
        case "good", "normal":
            return .normal
        case "fair", "replace soon":
            return .replaceSoon
        case "poor", "replace now":
            return .replaceNow
        case "check battery":
            break
        default:
            return .unknown
        }

        let capacityRatio = batteryHealthRatio(fullChargeCapacity: fullChargeCapacity, designCapacity: designCapacity)
        let cycleRatio = cycleRatio(cycleCount: cycleCount, designCycleCount: designCycleCount)
        let metricIsHealthy = (batteryHealthMetric ?? 0) <= 0

        if let capacityRatio, capacityRatio >= 0.8,
           let cycleRatio, cycleRatio < 0.9,
           metricIsHealthy {
            return .normal
        }

        if let capacityRatio, capacityRatio < 0.7 {
            return .serviceBattery
        }

        if let cycleRatio, cycleRatio >= 0.95,
           let capacityRatio, capacityRatio < 0.8 {
            return .serviceBattery
        }

        return .unknown
    }

    private func mapDirectCondition(_ value: String?) -> BatteryMetrics.BatteryCondition? {
        switch normalize(value) {
        case "service battery":
            return .serviceBattery
        case "replace soon":
            return .replaceSoon
        case "replace now":
            return .replaceNow
        case "good", "normal":
            return .normal
        default:
            return nil
        }
    }

    private func batteryHealthRatio(fullChargeCapacity: Int?, designCapacity: Int?) -> Double? {
        guard let fullChargeCapacity, let designCapacity, designCapacity > 0 else {
            return nil
        }

        return Double(fullChargeCapacity) / Double(designCapacity)
    }

    private func cycleRatio(cycleCount: Int?, designCycleCount: Int?) -> Double? {
        guard let cycleCount, let designCycleCount, designCycleCount > 0 else {
            return nil
        }

        return Double(cycleCount) / Double(designCycleCount)
    }

    private func normalize(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }
}
