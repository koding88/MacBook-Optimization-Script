import SwiftUI

struct SystemInfoView: View {
    enum MemoryCardEmphasis: Equatable {
        case normal
        case elevated
        case critical
    }

    struct BarSegment: Equatable {
        let bytes: Int64
        let color: Color
    }

    let summary: MachineSummary?
    let memoryMetrics: MemoryMetrics?
    let localizer: AppLocalizer
    private let cardSpacing: CGFloat = 14

    private var formatter: SystemInfoFormatter {
        SystemInfoFormatter(localizer: localizer)
    }

    var summaryLine: String {
        let memoryText = summary.map { formatter.memorySummary(memoryBytes: $0.memoryBytes) } ?? localizer.text(.unavailable)
        let chipText = summary?.chipName ?? localizer.text(.dashboardAppleSilicon)
        let systemText = summary?.systemVersion ?? "macOS"
        return [chipText, memoryText, systemText].joined(separator: " • ")
    }

    private var storageMetrics: StorageMetrics {
        let snapshot = summary?.storageSnapshot ?? StorageSnapshot(
            totalBytes: summary?.storageTotalBytes ?? 0,
            availableBytes: summary?.storageAvailableBytes ?? 0
        )
        let totalBytes = max(snapshot.totalBytes, 0)
        let availableBytes = max(snapshot.availableBytes, 0)
        let usedBytes = max(totalBytes - availableBytes, 0)
        let progress = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0

        return StorageMetrics(
            totalBytes: totalBytes,
            availableBytes: availableBytes,
            usedBytes: usedBytes,
            progress: progress
        )
    }

    private var chipSecondaryLine: String {
        [summary?.coreDescription, summary?.gpuDescription]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private var batterySummaryLine: String {
        guard let battery = summary?.battery else { return localizer.text(.unavailable) }

        if let condition = battery.condition, !condition.isEmpty {
            return condition
        }

        if let powerSource = battery.powerSource, !powerSource.isEmpty {
            return powerSource
        }

        return localizer.text(.unavailable)
    }

    private var batteryDetailLine: String? {
        guard let battery = summary?.battery else { return nil }
        guard let cycleCount = battery.cycleCount, !cycleCount.isEmpty else { return nil }
        return localizer.format(.dashboardCycleFormat, cycleCount)
    }

    private var storagePercentText: String {
        "\(Int((storageMetrics.progress * 100).rounded()))%"
    }

    private var memoryUsedBytes: UInt64 {
        if let memoryMetrics {
            return UInt64(max(memoryMetrics.usedBytes, 0))
        }
        guard let summary else { return 0 }
        return summary.memoryBytes / 2
    }

    private var memoryAvailableBytes: UInt64 {
        if let memoryMetrics {
            return UInt64(max(memoryMetrics.availableBytes, 0))
        }
        guard let summary else { return 0 }
        return summary.memoryBytes - memoryUsedBytes
    }

    private var batteryStatusText: String {
        guard let battery = summary?.battery else { return localizer.text(.unavailable) }

        if let powerSource = battery.powerSource, !powerSource.isEmpty {
            let lowercased = powerSource.lowercased()
            if lowercased.contains("ac") || lowercased.contains("adapter") || lowercased.contains("charging") {
                return localizer.text(.dashboardPowerSourceAC)
            }
        }

        if let charge = batteryPercent(from: battery.chargePercent), charge >= 99 {
            return localizer.text(.dashboardBatteryCharged)
        }

        return "On Battery"
    }

    private var batteryHealthText: String {
        guard let battery = summary?.battery else { return localizer.text(.unavailable) }
        if let condition = battery.condition, !condition.isEmpty {
            return condition
        }
        if let powerSource = battery.powerSource, !powerSource.isEmpty {
            return powerSource
        }
        return localizer.text(.unavailable)
    }

    var batterySemanticLine: String {
        guard summary?.battery != nil else { return localizer.text(.unavailable) }

        let health: String
        if batteryHealthText.localizedCaseInsensitiveContains("normal") ||
            batteryHealthText.localizedCaseInsensitiveContains("good") ||
            batteryHealthText.localizedCaseInsensitiveContains("healthy") {
            health = localizer.text(.dashboardBatteryHealthy)
        } else {
            health = batteryHealthText
        }

        return [batteryStatusText, health]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private var batteryPowerSourceText: String {
        guard let powerSource = summary?.battery?.powerSource, !powerSource.isEmpty else { return "" }
        let lowercased = powerSource.lowercased()
        if lowercased.contains("ac") || lowercased.contains("adapter") || lowercased.contains("charging") {
            return localizer.text(.dashboardPowerSourceAC)
        }
        return powerSource
    }

    private var batteryHealthSummaryText: String? {
        guard let battery = summary?.battery else { return nil }
        if let condition = battery.condition, !condition.isEmpty {
            return condition
        }
        return nil
    }

    var memoryUsedValueText: String {
        MemoryMetrics.format(bytes: Int64(memoryUsedBytes))
    }

    var memoryAvailableValueText: String {
        MemoryMetrics.format(bytes: Int64(memoryAvailableBytes))
    }

    var memoryEmphasis: MemoryCardEmphasis {
        guard let memoryMetrics else { return .normal }
        switch memoryMetrics.pressureLevel {
        case .normal:
            return .normal
        case .elevated:
            return .elevated
        case .critical:
            return .critical
        }
    }

    var memoryAccentColor: Color {
        switch memoryEmphasis {
        case .normal:
            return .purple
        case .elevated:
            return .orange
        case .critical:
            return .red
        }
    }

    var memoryBarSegments: [BarSegment] {
        guard let memoryMetrics else {
            return [
                BarSegment(bytes: Int64(memoryUsedBytes), color: memoryAccentColor),
                BarSegment(bytes: Int64(memoryAvailableBytes), color: .green)
            ]
        }

        return [
            BarSegment(bytes: max(memoryMetrics.appBytes, 0), color: memoryAccentColor),
            BarSegment(bytes: max(memoryMetrics.wiredBytes, 0), color: .orange),
            BarSegment(bytes: max(memoryMetrics.compressedBytes, 0), color: .pink),
            BarSegment(bytes: max(memoryMetrics.availableBytes, 0), color: .green)
        ]
    }

    var batteryFillRatio: Double {
        guard let charge = summary?.battery.flatMap({ batteryPercent(from: $0.chargePercent) }) else { return 0 }
        return min(max(Double(charge) / 100, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(summary: summary)
            masonryContent
        }
        .padding(.vertical, 6)
        .redacted(reason: summary == nil ? .placeholder : [])
        .allowsHitTesting(summary != nil)
    }

    @ViewBuilder
    private func header(summary: MachineSummary?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary, .secondary)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(summary?.marketingModel ?? "MacBook Pro")
                    .font(.title3.weight(.semibold))

                Text(summaryLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var masonryContent: some View {
        ViewThatFits(in: .horizontal) {
            wideMasonryContent
            compactMasonryContent
        }
    }

    private var wideMasonryContent: some View {
        VStack(spacing: cardSpacing) {
            HStack(alignment: .top, spacing: cardSpacing) {
                chipHeroCard
                storageHeroCard
            }

            HStack(alignment: .top, spacing: cardSpacing) {
                memoryCard
                batteryCard
            }

            HStack(alignment: .top, spacing: cardSpacing) {
                displayCard
                macOSCard
            }
        }
    }

    private var compactMasonryContent: some View {
        VStack(spacing: cardSpacing) {
            chipHeroCard
            storageHeroCard
            memoryCard
            batteryCard
            displayCard
            macOSCard
        }
    }

    private var chipHeroCard: some View {
        OverviewCard(
            role: .hero,
            symbolName: "cpu.fill",
            title: localizer.text(.systemLabelChip),
            symbolPrimaryColor: .blue,
            symbolSecondaryColor: .cyan,
            tintColor: .blue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(summary?.chipName ?? localizer.text(.dashboardAppleSilicon))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if !chipSecondaryLine.isEmpty {
                    Text(chipSecondaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    statBadge(
                        title: "CPU",
                        value: summary?.coreDescription ?? localizer.text(.unavailable),
                        tint: .blue
                    )
                    statBadge(
                        title: "GPU",
                        value: summary?.gpuDescription ?? localizer.text(.unavailable),
                        tint: .cyan
                    )
                }
            }
        }
    }

    private var storageHeroCard: some View {
        OverviewCard(
            role: .hero,
            symbolName: "internaldrive.fill",
            title: localizer.text(.systemLabelStorage),
            symbolPrimaryColor: .cyan,
            symbolSecondaryColor: .blue
            ,
            tintColor: .cyan
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(storagePercentText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(localizer.text(.commonUsed))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(
                    formatter.storageSummary(
                        totalBytes: storageMetrics.totalBytes,
                        availableBytes: storageMetrics.availableBytes
                    )
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

                StorageUsageBar(progress: storageMetrics.progress)
                    .frame(height: 10)

                HStack(spacing: 12) {
                    storageMetricColumn(title: localizer.text(.dashboardAvailable), value: byteCountString(storageMetrics.availableBytes))
                    Spacer(minLength: 12)
                    storageMetricColumn(title: localizer.text(.commonUsed), value: byteCountString(storageMetrics.usedBytes))
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var memoryCard: some View {
        OverviewCard(
            role: .medium,
            symbolName: "memorychip.fill",
            title: localizer.text(.systemLabelMemory),
            symbolPrimaryColor: memoryAccentColor,
            symbolSecondaryColor: memoryEmphasis == .normal ? .pink : memoryAccentColor.opacity(0.7),
            tintColor: memoryAccentColor
        ) {
            VStack(alignment: .leading, spacing: 7) {
                Text(summary.map { formatter.memorySummary(memoryBytes: $0.memoryBytes) } ?? localizer.text(.dashboardUnifiedMemory))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    storageMetricColumn(title: localizer.text(.commonUsed), value: memoryUsedValueText)
                    storageMetricColumn(title: localizer.text(.dashboardAvailable), value: memoryAvailableValueText)
                }

                usageBar(segments: memoryBarSegments)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                    .padding(.bottom, 4)

                Text(memoryPressureSupportText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var batteryCard: some View {
        OverviewCard(
            role: .medium,
            symbolName: "battery.100percent",
            title: localizer.text(.systemLabelBattery),
            symbolPrimaryColor: .green,
            symbolSecondaryColor: .yellow,
            tintColor: .green
        ) {
            VStack(alignment: .leading, spacing: 7) {
                Text(summary?.battery?.chargePercent ?? localizer.text(.unavailable))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(batteryColor(for: summary?.battery.flatMap { batteryPercent(from: $0.chargePercent) }))

                Text(batterySemanticLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                batteryLevelBar(fillRatio: batteryFillRatio)
                    .padding(.top, 2)
                    .padding(.bottom, 4)

                HStack(spacing: 10) {
                    storageMetricColumn(
                        title: localizer.text(.snapshotBatteryPowerSource),
                        value: batteryPowerSourceText.isEmpty ? batteryStatusText : batteryPowerSourceText
                    )

                    if let batteryDetailLine {
                        storageMetricColumn(
                            title: localizer.text(.snapshotBatteryCycleCount),
                            value: batteryDetailLine
                        )
                    } else if let health = batteryHealthSummaryText {
                        storageMetricColumn(
                            title: localizer.text(.batterySnapshotHealth),
                            value: health
                        )
                    }
                }
            }
        }
    }

    private var displayCard: some View {
        OverviewCard(
            role: .compact,
            symbolName: "display",
            title: localizer.text(.systemLabelDisplay),
            symbolPrimaryColor: .indigo,
            symbolSecondaryColor: .blue,
            tintColor: .indigo
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary?.displayName ?? localizer.text(.dashboardBuiltInDisplay))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(summary?.displayResolution ?? localizer.text(.unavailable))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var macOSCard: some View {
        OverviewCard(
            role: .compact,
            symbolName: "gearshape.2.fill",
            title: localizer.text(.systemLabelMacOS),
            symbolPrimaryColor: .gray,
            symbolSecondaryColor: .secondary,
            tintColor: .gray
        ) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary?.systemVersion ?? "macOS")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(localizer.text(.dashboardVersion))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statBadge(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func storageMetricColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private func usageBar(segments: [BarSegment]) -> some View {
        GeometryReader { proxy in
            let total = max(segments.map(\.bytes).reduce(0, +), 1)
            HStack(spacing: 3) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let width = max(proxy.size.width * CGFloat(Double(segment.bytes) / Double(total)), 0)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(segment.color.opacity(0.85))
                        .frame(width: width)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(height: 10)
    }

    private func batteryLevelBar(fillRatio: Double) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width * CGFloat(fillRatio), 0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(batteryColor(for: summary?.battery.flatMap { batteryPercent(from: $0.chargePercent) }).opacity(0.9))
                    .frame(width: width)
            }
        }
        .frame(height: 10)
    }

    private var memoryPressureSupportText: String {
        guard let memoryMetrics else {
            return localizer.text(.dashboardUnifiedMemory)
        }

        switch memoryMetrics.pressureLevel {
        case .normal:
            return localizer.text(.memorySnapshotPressureHintNormal)
        case .elevated:
            return localizer.text(.memorySnapshotPressureHintElevated)
        case .critical:
            return localizer.text(.memorySnapshotPressureHintCritical)
        }
    }

    private func byteCountString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: max(bytes, 0))
    }

    private func batteryPercent(from value: String) -> Int? {
        Int(value.replacingOccurrences(of: "%", with: ""))
    }

    private func batteryColor(for percent: Int?) -> Color {
        guard let percent else { return .secondary }
        switch percent {
        case 60...:
            return .green
        case 30..<60:
            return .orange
        default:
            return .red
        }
    }
}

private struct StorageMetrics {
    let totalBytes: Int64
    let availableBytes: Int64
    let usedBytes: Int64
    let progress: Double
}

private struct OverviewCard<Content: View>: View {
    enum Role {
        case hero
        case medium
        case compact

        var minHeight: CGFloat {
            switch self {
            case .hero:
                return 184
            case .medium:
                return 132
            case .compact:
                return 82
            }
        }

        var padding: CGFloat {
            switch self {
            case .hero:
                return 15
            case .medium:
                return 13
            case .compact:
                return 10
            }
        }

        var titleFont: Font {
            switch self {
            case .hero, .medium:
                return .subheadline.weight(.semibold)
            case .compact:
                return .caption.weight(.semibold)
            }
        }
    }

    let role: Role
    let symbolName: String
    let title: String
    let symbolPrimaryColor: Color
    let symbolSecondaryColor: Color
    let tintColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: role == .compact ? 8 : 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(symbolPrimaryColor, symbolSecondaryColor)
                    .frame(width: 28, height: 28)
                    .background(tintColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(role.titleFont)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(role.padding)
        .frame(maxWidth: .infinity, minHeight: role.minHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tintColor.opacity(role == .compact ? 0.03 : 0.05))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        )
    }
}

private struct StorageUsageBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)
            let usedWidth = max(proxy.size.width * clampedProgress, 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: usedWidth)
            }
        }
        .frame(height: 9)
    }
}
