import Foundation

struct StorageSnapshot: Equatable {
    let totalBytes: Int64
    let availableBytes: Int64
    let usedBytes: Int64

    init(totalBytes: Int64, availableBytes: Int64) {
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.usedBytes = totalBytes - availableBytes
    }
}

struct MachineSummary: Equatable {
    let modelName: String
    let marketingModel: String
    let chip: String
    let coreDescription: String?
    let gpuDescription: String?
    let memoryBytes: UInt64
    let storageTotalBytes: Int64
    let storageAvailableBytes: Int64
    let displayName: String
    let displayResolution: String
    let storageSnapshot: StorageSnapshot?
    let systemVersion: String
    let battery: BatterySummary?
    let serialNumber: String?

    init(
        modelName: String,
        marketingModel: String,
        chip: String,
        coreDescription: String? = nil,
        gpuDescription: String? = nil,
        memoryBytes: UInt64,
        storageTotalBytes: Int64,
        storageAvailableBytes: Int64,
        displayName: String,
        displayResolution: String,
        storageSnapshot: StorageSnapshot? = nil,
        systemVersion: String,
        battery: BatterySummary?,
        serialNumber: String? = nil
    ) {
        self.modelName = modelName
        self.marketingModel = marketingModel
        self.chip = chip
        self.coreDescription = coreDescription
        self.gpuDescription = gpuDescription
        self.memoryBytes = memoryBytes
        self.storageTotalBytes = storageTotalBytes
        self.storageAvailableBytes = storageAvailableBytes
        self.displayName = displayName
        self.displayResolution = displayResolution
        self.storageSnapshot = storageSnapshot
        self.systemVersion = systemVersion
        self.battery = battery
        self.serialNumber = serialNumber
    }

    init(
        modelName: String,
        chipName: String,
        memory: String,
        storage: String,
        storageSnapshot: StorageSnapshot? = nil,
        systemVersion: String,
        battery: BatterySummary?,
        serialNumber: String?
    ) {
        self.init(
            modelName: modelName,
            marketingModel: modelName,
            chip: chipName,
            coreDescription: nil,
            gpuDescription: nil,
            memoryBytes: 0,
            storageTotalBytes: storageSnapshot?.totalBytes ?? 0,
            storageAvailableBytes: storageSnapshot?.availableBytes ?? 0,
            displayName: "Built-in Display",
            displayResolution: "Unavailable",
            storageSnapshot: storageSnapshot,
            systemVersion: systemVersion,
            battery: battery,
            serialNumber: serialNumber
        )
    }

    var chipName: String { chip }
}

struct BatterySummary: Equatable {
    let chargePercent: String
    let condition: String?
    let cycleCount: String?
    let powerSource: String?
}

enum ActivityEventType: String, Equatable {
    case info
    case success
    case warning
    case error

    init(kind: ActivityKind) {
        switch kind {
        case .info:
            self = .info
        case .success:
            self = .success
        case .warning:
            self = .warning
        case .failure:
            self = .error
        }
    }
}

struct ActivityEvent: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let type: ActivityEventType
    let title: String
    let message: String
    let symbolName: String

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        type: ActivityEventType,
        title: String,
        message: String,
        symbolName: String = "info.circle"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.title = title
        self.message = message
        self.symbolName = symbolName
    }
}

enum ActivityKind {
    case info
    case success
    case warning
    case failure
}

struct ActivityItem: Identifiable, Equatable {
    let event: ActivityEvent

    init(title: String, message: String, date: Date, kind: ActivityKind, symbolName: String) {
        self.event = ActivityEvent(
            timestamp: date,
            type: ActivityEventType(kind: kind),
            title: title,
            message: message,
            symbolName: symbolName
        )
    }

    init(event: ActivityEvent) {
        self.event = event
    }

    var id: UUID { event.id }
    var title: String { event.title }
    var message: String { event.message }
    var date: Date { event.timestamp }
    var kind: ActivityKind {
        switch event.type {
        case .info:
            return .info
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .failure
        }
    }
    var symbolName: String { event.symbolName }
}
