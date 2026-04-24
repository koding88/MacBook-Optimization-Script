import Foundation

enum MemorySnapshotPresentation {
    private static let usageBreakdownOuterPadding: CGFloat = 4

    enum ChangedField: Hashable {
        case pressure
        case usage
        case swap
    }

    enum Emphasis: Equatable {
        case normal
        case warning
        case critical
    }

    struct HeaderPalette: Equatable {
        let iconSymbol: String
        let statusSymbol: String
        let emphasis: Emphasis
    }

    struct UsageBreakdownItem: Equatable {
        let titleKey: LocalizedKey
        let valueBytes: Int64
        let iconSymbol: String
    }

    static func changedFields(from previous: MemoryMetrics?, to current: MemoryMetrics) -> Set<ChangedField> {
        guard let previous else {
            return [.pressure, .usage, .swap]
        }

        var changedFields = Set<ChangedField>()

        if previous.pressureLevel != current.pressureLevel || abs(previous.pressureScore - current.pressureScore) >= 0.03 {
            changedFields.insert(.pressure)
        }

        if previous.usedBytes != current.usedBytes || previous.cachedBytes != current.cachedBytes {
            changedFields.insert(.usage)
        }

        if previous.swapUsedBytes != current.swapUsedBytes {
            changedFields.insert(.swap)
        }

        return changedFields
    }

    static func headerPalette(for metrics: MemoryMetrics) -> HeaderPalette {
        switch metrics.pressureLevel {
        case .normal:
            return HeaderPalette(iconSymbol: "memorychip.fill", statusSymbol: "waveform.path.ecg", emphasis: .normal)
        case .elevated:
            return HeaderPalette(iconSymbol: "memorychip.fill", statusSymbol: "exclamationmark.circle.fill", emphasis: .warning)
        case .critical:
            return HeaderPalette(iconSymbol: "memorychip.fill", statusSymbol: "flame.fill", emphasis: .critical)
        }
    }

    static func usageBreakdownItems(for metrics: MemoryMetrics) -> [UsageBreakdownItem] {
        [
            UsageBreakdownItem(titleKey: .memorySnapshotAppMemory, valueBytes: metrics.appBytes, iconSymbol: "app.badge.fill"),
            UsageBreakdownItem(titleKey: .memorySnapshotWiredMemory, valueBytes: metrics.wiredBytes, iconSymbol: "cpu.fill"),
            UsageBreakdownItem(titleKey: .memorySnapshotCompressed, valueBytes: metrics.compressedBytes, iconSymbol: "square.stack.3d.down.right.fill"),
            UsageBreakdownItem(titleKey: .memorySnapshotCachedFiles, valueBytes: metrics.cachedBytes, iconSymbol: "externaldrive.fill"),
            UsageBreakdownItem(titleKey: .memorySnapshotFreeMemory, valueBytes: metrics.freeBytes, iconSymbol: "circlebadge")
        ]
    }

    static func usageBreakdownBarAvailableWidth(
        totalWidth: CGFloat,
        itemCount: Int,
        spacing: CGFloat,
        horizontalPadding: CGFloat = usageBreakdownOuterPadding
    ) -> CGFloat {
        let clampedItemCount = max(itemCount, 0)
        let totalSpacing = spacing * CGFloat(max(clampedItemCount - 1, 0))
        let totalPadding = horizontalPadding * 2
        return max(totalWidth - totalSpacing - totalPadding, 0)
    }

    static func usageBreakdownSegmentWidths(
        values: [Int64],
        totalWidth: CGFloat,
        spacing: CGFloat,
        horizontalPadding: CGFloat = usageBreakdownOuterPadding
    ) -> [CGFloat] {
        let availableWidth = usageBreakdownBarAvailableWidth(
            totalWidth: totalWidth,
            itemCount: values.count,
            spacing: spacing,
            horizontalPadding: horizontalPadding
        )

        let positiveValues = values.map { max($0, 0) }
        let totalValue = positiveValues.reduce(0, +)

        guard availableWidth > 0, totalValue > 0 else {
            return Array(repeating: 0, count: values.count)
        }

        var widths = positiveValues.map { availableWidth * CGFloat(Double($0) / Double(totalValue)) }
        let usedWidth = widths.reduce(0, +)
        let correction = availableWidth - usedWidth

        if let lastIndex = widths.indices.last {
            widths[lastIndex] = max(widths[lastIndex] + correction, 0)
        }

        return widths
    }
}
