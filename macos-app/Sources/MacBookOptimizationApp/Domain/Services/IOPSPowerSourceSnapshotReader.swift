import Foundation
import IOKit.ps

protocol PowerSourceSnapshotReading {
    func internalBatteryDescription() throws -> [String: Any]
    func externalPowerAdapterDetails() -> [String: Any]
    func intValue(for key: String, in dictionary: [String: Any]) -> Int?
    func boolValue(for key: String, in dictionary: [String: Any]) -> Bool?
    func stringValue(for key: String, in dictionary: [String: Any]) -> String?
}

struct IOPSPowerSourceSnapshotReader: PowerSourceSnapshotReading {
    func internalBatteryDescription() throws -> [String: Any] {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let powerSources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        for powerSource in powerSources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, powerSource as CFTypeRef)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if stringValue(for: Self.typeKey, in: description) == Self.internalBatteryType {
                return description
            }
        }

        throw BatteryMonitoringError.snapshotUnavailable
    }

    func externalPowerAdapterDetails() -> [String: Any] {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }

        return details
    }

    func intValue(for key: String, in dictionary: [String: Any]) -> Int? {
        if let number = dictionary[key] as? NSNumber {
            return number.intValue
        }

        return dictionary[key] as? Int
    }

    func boolValue(for key: String, in dictionary: [String: Any]) -> Bool? {
        if let value = dictionary[key] as? Bool {
            return value
        }

        if let number = dictionary[key] as? NSNumber {
            return number.boolValue
        }

        return nil
    }

    func stringValue(for key: String, in dictionary: [String: Any]) -> String? {
        if let value = dictionary[key] as? String {
            return value
        }

        if let value = dictionary[key] as? NSString {
            return value as String
        }

        return nil
    }

    static let currentCapacityKey = String(describing: kIOPSCurrentCapacityKey)
    static let powerSourceStateKey = String(describing: kIOPSPowerSourceStateKey)
    static let isChargingKey = String(describing: kIOPSIsChargingKey)
    static let isChargedKey = String(describing: kIOPSIsChargedKey)
    static let typeKey = String(describing: kIOPSTypeKey)
    static let hardwareSerialNumberKey = String(describing: kIOPSHardwareSerialNumberKey)
    static let batteryHealthKey = String(describing: kIOPSBatteryHealthKey)
    static let batteryHealthConditionKey = String(describing: kIOPSBatteryHealthConditionKey)
    static let adapterWattsKey = String(describing: kIOPSPowerAdapterWattsKey)
    static let internalBatteryType = String(describing: kIOPSInternalBatteryType)
    static let acPowerValue = String(describing: kIOPSACPowerValue)
    static let batteryPowerValue = String(describing: kIOPSBatteryPowerValue)
}
