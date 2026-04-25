import Foundation

struct SystemSnapshotProvider {
    struct StorageResourceValues {
        let totalCapacity: Int?
        let availableCapacity: Int?
        let availableCapacityForImportantUsage: Int64?
    }

    private let resourceValuesProvider: () throws -> StorageResourceValues

    init(
        resourceValuesProvider: @escaping () throws -> StorageResourceValues = {
            let values = try URL(fileURLWithPath: "/").resourceValues(
                forKeys: [
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeAvailableCapacityForImportantUsageKey
                ]
            )

            return StorageResourceValues(
                totalCapacity: values.volumeTotalCapacity,
                availableCapacity: values.volumeAvailableCapacity,
                availableCapacityForImportantUsage: values.volumeAvailableCapacityForImportantUsage
            )
        }
    ) {
        self.resourceValuesProvider = resourceValuesProvider
    }

    func storageSnapshot(
        totalBytesOverride: Int64? = nil,
        availableBytesOverride: Int64? = nil
    ) async -> StorageSnapshot {
        if let totalBytesOverride, let availableBytesOverride {
            return StorageSnapshot(totalBytes: totalBytesOverride, availableBytes: availableBytesOverride)
        }

        do {
            let values = try resourceValuesProvider()
            let totalBytes = Int64(values.totalCapacity ?? 0)
            let availableBytes = values.availableCapacityForImportantUsage ?? Int64(values.availableCapacity ?? 0)
            return StorageSnapshot(totalBytes: totalBytes, availableBytes: availableBytes)
        } catch {
            return StorageSnapshot(totalBytes: 0, availableBytes: 0)
        }
    }
}
