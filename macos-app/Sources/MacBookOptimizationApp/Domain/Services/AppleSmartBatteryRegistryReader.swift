import Foundation
import IOKit

protocol AppleSmartBatteryRegistryReading {
    func properties() throws -> [String: Any]
    func adapterDetails(from properties: [String: Any]) -> [String: Any]
    func intValue(for key: String, in dictionary: [String: Any]) -> Int?
    func stringValue(for key: String, in dictionary: [String: Any]) -> String?
    func temperature(from properties: [String: Any]) -> Double?
    func manufactureDate(from properties: [String: Any]) -> Date?
    func batteryData(from properties: [String: Any]) -> [String: Any]
}

struct AppleSmartBatteryRegistryReader: AppleSmartBatteryRegistryReading {
    func properties() throws -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(Self.appleSmartBatteryClass))
        guard service != 0 else {
            throw BatteryMonitoringError.snapshotUnavailable
        }
        defer { IOObjectRelease(service) }

        var propertiesRef: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &propertiesRef, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS,
              let properties = propertiesRef?.takeRetainedValue() as? [String: Any] else {
            throw BatteryMonitoringError.snapshotUnavailable
        }

        return properties
    }

    func adapterDetails(from properties: [String: Any]) -> [String: Any] {
        properties[Self.adapterDetailsKey] as? [String: Any] ?? [:]
    }

    func batteryData(from properties: [String: Any]) -> [String: Any] {
        properties[Self.batteryDataKey] as? [String: Any] ?? [:]
    }

    func intValue(for key: String, in dictionary: [String: Any]) -> Int? {
        if let number = dictionary[key] as? NSNumber {
            return number.intValue
        }

        return dictionary[key] as? Int
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

    func temperature(from properties: [String: Any]) -> Double? {
        guard let rawTemperature = intValue(for: Self.temperatureKey, in: properties) else {
            return nil
        }

        return (Double(rawTemperature) / 10.0) - 273.15
    }

    func manufactureDate(from properties: [String: Any]) -> Date? {
        let rawManufactureDate =
            (properties[Self.manufactureDateKey] as? NSNumber)
            ?? ((properties[Self.batteryDataKey] as? [String: Any])?[Self.manufactureDateKey] as? NSNumber)
        let serialNumber =
            stringValue(for: Self.serialKey, in: properties)
            ?? stringValue(for: Self.serialKey, in: (properties[Self.batteryDataKey] as? [String: Any]) ?? [:])

        guard let rawManufactureDate else {
            return serialNumber.flatMap(decodeManufactureDateFromSerial(_:))
        }

        let value = rawManufactureDate.int64Value
        if value > 1_000_000_000 {
            return serialNumber.flatMap(decodeManufactureDateFromSerial(_:))
        }

        return decodePackedManufactureDate(Int(value))
    }

    private func decodePackedManufactureDate(_ rawValue: Int) -> Date? {
        let day = rawValue & 0x1F
        let month = (rawValue >> 5) & 0x0F
        let year = ((rawValue >> 9) & 0x7F) + 1980

        guard day > 0, month > 0 else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)
    }

    private func decodeManufactureDateFromSerial(_ serial: String) -> Date? {
        guard serial.count >= 7 else { return nil }

        let yearIndex = serial.index(serial.startIndex, offsetBy: 3)
        let weekStart = serial.index(serial.startIndex, offsetBy: 4)
        let weekEnd = serial.index(serial.startIndex, offsetBy: 6)
        let dayIndex = serial.index(serial.startIndex, offsetBy: 6)

        guard
            let yearDigit = Int(String(serial[yearIndex])),
            let weekOfYear = Int(serial[weekStart..<weekEnd]),
            let weekdayOffset = Int(String(serial[dayIndex])),
            (1...53).contains(weekOfYear),
            (1...7).contains(weekdayOffset)
        else {
            return nil
        }

        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        let currentDecade = (currentYear / 10) * 10
        var year = currentDecade + yearDigit
        if year > currentYear {
            year -= 10
        }

        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = weekOfYear
        components.weekday = weekdayOffset
        return Calendar(identifier: .gregorian).date(from: components)
    }

    private static let appleSmartBatteryClass = "AppleSmartBattery"

    static let cycleCountKey = "CycleCount"
    static let designCapacityKey = "DesignCapacity"
    static let nominalChargeCapacityKey = "NominalChargeCapacity"
    static let appleRawMaxCapacityKey = "AppleRawMaxCapacity"
    static let appleRawCurrentCapacityKey = "AppleRawCurrentCapacity"
    static let designCycleCountKey = "DesignCycleCount9C"
    static let batteryHealthMetricKey = "BatteryHealthMetric"
    static let adapterDetailsKey = "AdapterDetails"
    static let adapterNameKey = "Name"
    static let adapterDescriptionKey = "Description"
    static let temperatureKey = "Temperature"
    static let manufactureDateKey = "ManufactureDate"
    static let batteryDataKey = "BatteryData"
    static let serialKey = "Serial"
}
