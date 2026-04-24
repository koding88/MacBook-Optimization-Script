import Foundation

enum BatterySnapshotPresentation {
    enum ChangedField: Hashable {
        case level
        case powerSource
        case chargingState
        case health
        case charger
        case temperature
        case lowPowerMode
    }

    static func levelInsight(metrics: BatteryMetrics, localizer: AppLocalizer) -> String {
        if metrics.level >= 100, metrics.powerSource == .ac, metrics.chargingState == .charged {
            return localizer.text(.batterySnapshotInsightLevelChargedAC)
        }

        if metrics.powerSource == .ac, metrics.chargingState == .charging {
            return localizer.format(.batterySnapshotInsightLevelChargingAC, metrics.level)
        }

        if metrics.powerSource == .battery, metrics.chargingState == .discharging {
            return localizer.format(.batterySnapshotInsightLevelBatteryPower, metrics.level)
        }

        return localizer.format(.batterySnapshotInsightLevelGeneric, metrics.level)
    }

    static func healthInsight(metrics: BatteryMetrics, localizer: AppLocalizer) -> String {
        if let health = metrics.healthPercentage {
            return localizer.format(.batterySnapshotInsightHealthStable, health)
        }

        return localizer.format(.batterySnapshotInsightHealthCondition, metrics.condition.displayName)
    }

    static func chargerInsight(metrics: BatteryMetrics, localizer: AppLocalizer) -> String {
        if let wattage = metrics.chargerWattage, let adapter = metrics.chargerAdapterName {
            return localizer.format(.batterySnapshotInsightChargerDetected, wattage, adapter)
        }

        if let wattage = metrics.chargerWattage {
            return localizer.format(.batterySnapshotInsightChargerWattageOnly, wattage)
        }

        if metrics.powerSource == .battery {
            return localizer.text(.batterySnapshotInsightChargerBatteryOnly)
        }

        return localizer.text(.batterySnapshotInsightChargerUnavailable)
    }

    static func detailInsight(metrics: BatteryMetrics, localizer: AppLocalizer) -> String {
        switch metrics.temperatureStatus {
        case .normal:
            return localizer.text(.batterySnapshotInsightTemperatureNormal)
        case .elevated:
            return localizer.text(.batterySnapshotInsightTemperatureElevated)
        case .high:
            return localizer.text(.batterySnapshotInsightTemperatureHigh)
        case .unknown:
            if metrics.isLowPowerModeEnabled == true {
                return localizer.text(.batterySnapshotInsightLowPowerEnabled)
            }
            return localizer.text(.batterySnapshotInsightDetailsUnavailable)
        }
    }

    static func lastUpdatedText(updatedAt: Date?, now: Date = Date(), localizer: AppLocalizer) -> String {
        guard let updatedAt else {
            return localizer.text(.batterySnapshotUpdatedUnavailable)
        }

        let delta = now.timeIntervalSince(updatedAt)
        if delta < 5 {
            return localizer.text(.batterySnapshotUpdatedJustNow)
        }

        return localizer.format(
            .batterySnapshotUpdatedAt,
            updatedAt.formatted(.dateTime.hour().minute().second())
        )
    }

    static func changedFields(from previous: BatteryMetrics?, to current: BatteryMetrics) -> Set<ChangedField> {
        guard let previous else {
            return [.level, .powerSource, .chargingState, .health, .charger, .temperature, .lowPowerMode]
        }

        var changed: Set<ChangedField> = []

        if previous.level != current.level {
            changed.insert(.level)
        }
        if previous.powerSource != current.powerSource {
            changed.insert(.powerSource)
        }
        if previous.chargingState != current.chargingState {
            changed.insert(.chargingState)
        }
        if previous.healthPercentage != current.healthPercentage || previous.condition != current.condition {
            changed.insert(.health)
        }
        if previous.chargerWattage != current.chargerWattage || previous.chargerAdapterName != current.chargerAdapterName {
            changed.insert(.charger)
        }
        if previous.temperature != current.temperature {
            changed.insert(.temperature)
        }
        if previous.isLowPowerModeEnabled != current.isLowPowerModeEnabled {
            changed.insert(.lowPowerMode)
        }

        return changed
    }
}
