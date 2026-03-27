import Foundation

struct SystemSnapshotProvider {
    func storageSnapshot(
        totalBytesOverride: Int64? = nil,
        availableBytesOverride: Int64? = nil
    ) async -> StorageSnapshot {
        if let totalBytesOverride, let availableBytesOverride {
            return StorageSnapshot(totalBytes: totalBytesOverride, availableBytes: availableBytesOverride)
        }

        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            let totalBytes = Int64(values.volumeTotalCapacity ?? 0)
            let availableBytes = Int64(values.volumeAvailableCapacity ?? 0)
            return StorageSnapshot(totalBytes: totalBytes, availableBytes: availableBytes)
        } catch {
            return StorageSnapshot(totalBytes: 0, availableBytes: 0)
        }
    }
}
