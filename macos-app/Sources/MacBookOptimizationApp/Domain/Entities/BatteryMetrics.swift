import Foundation

struct BatteryMetrics: Equatable {
    enum PowerSource: String, Equatable {
        case ac = "AC Power"
        case battery = "Battery Power"
        case unknown = "Unknown"

        var localizedKey: LocalizedKey {
            switch self {
            case .ac: .batteryPowerSourceAC
            case .battery: .batteryPowerSourceBattery
            case .unknown: .unavailable
            }
        }
    }

    enum ChargingState: String, Equatable {
        case charging = "Charging"
        case discharging = "Discharging"
        case charged = "Charged"
        case acAttached = "AC Attached; Not Charging"
        case unknown = "Unknown"

        var localizedKey: LocalizedKey {
            switch self {
            case .charging: .batteryStateCharging
            case .discharging: .batteryStateDischarging
            case .charged: .batteryStateCharged
            case .acAttached: .batteryStateACAttached
            case .unknown: .batteryStateNotCharging
            }
        }
    }

    enum BatteryCondition: String, Equatable {
        case normal = "Normal"
        case replaceSoon = "Replace Soon"
        case replaceNow = "Replace Now"
        case serviceBattery = "Service Battery"
        case unknown = "Unknown"

        var localizedKey: LocalizedKey {
            switch self {
            case .normal: .batteryConditionNormal
            case .replaceSoon: .batteryConditionReplaceSoon
            case .replaceNow: .batteryConditionReplaceNow
            case .serviceBattery: .batteryConditionServiceBattery
            case .unknown: .unavailable
            }
        }

        var isHealthy: Bool {
            self == .normal
        }
    }

    enum TemperatureStatus {
        case normal
        case elevated
        case high
        case unknown
    }

    let timestamp: Date
    let level: Int
    let powerSource: PowerSource
    let chargingState: ChargingState
    let condition: BatteryCondition
    let cycleCount: Int
    let fullChargeCapacity: Int?
    let designCapacity: Int?
    let currentCharge: Int?
    let chargerWattage: Int?
    let chargerAdapterName: String?
    let temperature: Double?
    let manufactureDate: Date?
    let serialNumber: String?
    let isLowPowerModeEnabled: Bool?

    var healthPercentage: Double? {
        guard let full = fullChargeCapacity,
              let design = designCapacity,
              design > 0 else {
            return nil
        }

        return min(Double(full) / Double(design) * 100.0, 100.0)
    }

    var isCharging: Bool {
        chargingState == .charging
    }

    var isOnACPower: Bool {
        powerSource == .ac
    }

    var hasChargerInfo: Bool {
        chargerWattage != nil || chargerAdapterName != nil
    }

    var temperatureStatus: TemperatureStatus {
        guard let temp = temperature else { return .unknown }
        if temp < 30 { return .normal }
        if temp <= 40 { return .elevated }
        return .high
    }
}
