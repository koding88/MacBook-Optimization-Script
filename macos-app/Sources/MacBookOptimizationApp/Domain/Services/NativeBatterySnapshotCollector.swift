import Foundation

protocol BatterySnapshotCollecting {
    func collectSnapshot() throws -> BatteryMetrics
}

struct NativeBatterySnapshotCollector: BatterySnapshotCollecting {
    private let powerSourceReader: PowerSourceSnapshotReading
    private let registryReader: AppleSmartBatteryRegistryReading
    private let systemConditionProvider: () -> BatteryMetrics.BatteryCondition?
    private let nativeConditionResolver: NativeBatteryConditionResolver
    private let lowPowerModeProvider: () -> Bool

    init(
        powerSourceReader: PowerSourceSnapshotReading = IOPSPowerSourceSnapshotReader(),
        registryReader: AppleSmartBatteryRegistryReading = AppleSmartBatteryRegistryReader(),
        systemConditionProvider: @escaping () -> BatteryMetrics.BatteryCondition? = {
            SystemBatteryConditionProvider().currentCondition()
        },
        nativeConditionResolver: NativeBatteryConditionResolver = NativeBatteryConditionResolver(),
        lowPowerModeProvider: @escaping () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled }
    ) {
        self.powerSourceReader = powerSourceReader
        self.registryReader = registryReader
        self.systemConditionProvider = systemConditionProvider
        self.nativeConditionResolver = nativeConditionResolver
        self.lowPowerModeProvider = lowPowerModeProvider
    }

    func collectSnapshot() throws -> BatteryMetrics {
        let powerSourceDescription = try powerSourceReader.internalBatteryDescription()
        let registryProperties = try registryReader.properties()
        let batteryData = registryReader.batteryData(from: registryProperties)
        let adapterDetails = powerSourceReader.externalPowerAdapterDetails()
        let registryAdapterDetails = registryReader.adapterDetails(from: registryProperties)
        let cycleCount = registryReader.intValue(for: AppleSmartBatteryRegistryReader.cycleCountKey, in: registryProperties) ?? 0
        let fullChargeCapacity = registryReader.intValue(for: AppleSmartBatteryRegistryReader.nominalChargeCapacityKey, in: registryProperties)
            ?? registryReader.intValue(for: AppleSmartBatteryRegistryReader.appleRawMaxCapacityKey, in: registryProperties)
        let designCapacity = registryReader.intValue(for: AppleSmartBatteryRegistryReader.designCapacityKey, in: registryProperties)

        let level = powerSourceReader.intValue(for: IOPSPowerSourceSnapshotReader.currentCapacityKey, in: powerSourceDescription) ?? 0
        let powerSource = mapPowerSource(powerSourceReader.stringValue(for: IOPSPowerSourceSnapshotReader.powerSourceStateKey, in: powerSourceDescription))
        let nativeCondition = nativeConditionResolver.resolve(
            iopsCondition: powerSourceReader.stringValue(for: IOPSPowerSourceSnapshotReader.batteryHealthConditionKey, in: powerSourceDescription),
            iopsHealth: powerSourceReader.stringValue(for: IOPSPowerSourceSnapshotReader.batteryHealthKey, in: powerSourceDescription),
            cycleCount: cycleCount,
            designCycleCount: registryReader.intValue(for: AppleSmartBatteryRegistryReader.designCycleCountKey, in: registryProperties),
            fullChargeCapacity: fullChargeCapacity,
            designCapacity: designCapacity,
            batteryHealthMetric: registryReader.intValue(for: AppleSmartBatteryRegistryReader.batteryHealthMetricKey, in: batteryData)
        )

        return BatteryMetrics(
            timestamp: Date(),
            level: level,
            powerSource: powerSource,
            chargingState: mapChargingState(description: powerSourceDescription, powerSource: powerSource),
            condition: mapCondition(nativeCondition: nativeCondition, systemCondition: systemConditionProvider()),
            cycleCount: cycleCount,
            fullChargeCapacity: fullChargeCapacity,
            designCapacity: designCapacity,
            currentCharge: registryReader.intValue(for: AppleSmartBatteryRegistryReader.appleRawCurrentCapacityKey, in: registryProperties),
            chargerWattage: powerSourceReader.intValue(for: IOPSPowerSourceSnapshotReader.adapterWattsKey, in: adapterDetails),
            chargerAdapterName: registryReader.stringValue(for: AppleSmartBatteryRegistryReader.adapterNameKey, in: registryAdapterDetails)
                ?? registryReader.stringValue(for: AppleSmartBatteryRegistryReader.adapterDescriptionKey, in: registryAdapterDetails),
            temperature: registryReader.temperature(from: registryProperties),
            manufactureDate: registryReader.manufactureDate(from: registryProperties),
            serialNumber: powerSourceReader.stringValue(for: IOPSPowerSourceSnapshotReader.hardwareSerialNumberKey, in: powerSourceDescription)
                ?? registryReader.stringValue(for: AppleSmartBatteryRegistryReader.serialKey, in: registryProperties),
            isLowPowerModeEnabled: lowPowerModeProvider()
        )
    }

    private func mapPowerSource(_ value: String?) -> BatteryMetrics.PowerSource {
        switch value {
        case IOPSPowerSourceSnapshotReader.acPowerValue:
            return .ac
        case IOPSPowerSourceSnapshotReader.batteryPowerValue:
            return .battery
        default:
            return .unknown
        }
    }

    private func mapChargingState(description: [String: Any], powerSource: BatteryMetrics.PowerSource) -> BatteryMetrics.ChargingState {
        if powerSourceReader.boolValue(for: IOPSPowerSourceSnapshotReader.isChargedKey, in: description) == true {
            return .charged
        }

        if powerSourceReader.boolValue(for: IOPSPowerSourceSnapshotReader.isChargingKey, in: description) == true {
            return .charging
        }

        switch powerSource {
        case .ac:
            return .acAttached
        case .battery:
            return .discharging
        case .unknown:
            return .unknown
        }
    }

    private func mapCondition(
        nativeCondition: BatteryMetrics.BatteryCondition,
        systemCondition: BatteryMetrics.BatteryCondition?
    ) -> BatteryMetrics.BatteryCondition {
        if nativeCondition != .unknown {
            return nativeCondition
        }

        if let systemCondition, systemCondition != .unknown {
            return systemCondition
        }

        return .unknown
    }
}
