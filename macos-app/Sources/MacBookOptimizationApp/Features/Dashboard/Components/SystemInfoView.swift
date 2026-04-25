import SwiftUI

struct SystemInfoView: View {
    let summary: MachineSummary?
    let localizer: AppLocalizer

    private let placeholderCardCount = 6

    private var formatter: SystemInfoFormatter {
        SystemInfoFormatter(localizer: localizer)
    }

    struct DetailRow: Equatable {
        let label: String
        let value: String
        let secondaryValue: String?
    }

    private let gridColumns = [
        GridItem(.flexible(minimum: 220), spacing: 16, alignment: .top),
        GridItem(.flexible(minimum: 220), spacing: 16, alignment: .top)
    ]

    var detailRows: [DetailRow] {
        guard let summary else { return [] }

        var rows = [
            DetailRow(label: localizer.text(.systemLabelChip), value: summary.chipName, secondaryValue: nil)
        ]

        if let coreDescription = summary.coreDescription {
            let combinedDetails = [coreDescription, summary.gpuDescription].compactMap { $0 }.joined(separator: " • ")
            rows[0] = DetailRow(
                label: localizer.text(.systemLabelChip),
                value: summary.chipName,
                secondaryValue: combinedDetails.isEmpty ? nil : combinedDetails
            )
        }

        rows.append(
            DetailRow(
                label: localizer.text(.systemLabelMemory),
                value: formatter.memorySummary(memoryBytes: summary.memoryBytes),
                secondaryValue: nil
            )
        )
        rows.append(
            DetailRow(
                label: localizer.text(.systemLabelStorage),
                value: formatter.storageSummary(
                    totalBytes: summary.storageTotalBytes,
                    availableBytes: summary.storageAvailableBytes
                ),
                secondaryValue: nil
            )
        )
        rows.append(
            DetailRow(
                label: localizer.text(.systemLabelDisplay),
                value: summary.displayName,
                secondaryValue: summary.displayResolution
            )
        )

        if let battery = summary.battery {
            rows.append(DetailRow(label: localizer.text(.systemLabelBattery), value: battery.chargePercent, secondaryValue: nil))
        }

        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(summary: summary)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                if let summary {
                    specCard(
                        title: localizer.text(.systemLabelChip),
                        symbolName: "cpu.fill",
                        symbolPrimaryColor: .blue,
                        symbolSecondaryColor: .cyan,
                        primaryValue: summary.chipName,
                        secondaryValue: [summary.coreDescription, summary.gpuDescription]
                            .compactMap { $0 }
                            .joined(separator: " • ")
                    )

                    specCard(
                        title: localizer.text(.systemLabelMemory),
                        symbolName: "memorychip.fill",
                        symbolPrimaryColor: .purple,
                        symbolSecondaryColor: .pink,
                        primaryValue: formatter.memorySummary(memoryBytes: summary.memoryBytes)
                    )

                    storageCard(summary: summary)

                    batteryCard(summary: summary)

                    specCard(
                        title: localizer.text(.systemLabelDisplay),
                        symbolName: "display",
                        symbolPrimaryColor: .indigo,
                        symbolSecondaryColor: .blue,
                        primaryValue: summary.displayName,
                        secondaryValue: summary.displayResolution
                    )

                    specCard(
                        title: localizer.text(.systemLabelMacOS),
                        symbolName: "gearshape.2.fill",
                        symbolPrimaryColor: .orange,
                        symbolSecondaryColor: .yellow,
                        primaryValue: summary.systemVersion,
                        secondaryValue: nil
                    )
                } else {
                    ForEach(0..<placeholderCardCount, id: \.self) { _ in
                        placeholderCard
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .redacted(reason: summary == nil ? .placeholder : [])
        .allowsHitTesting(summary != nil)
    }

    @ViewBuilder
    private func header(summary: MachineSummary?) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 60, height: 60)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(summary?.marketingModel ?? "MacBook Pro")
                    .font(.title2.weight(.semibold))

                if let summary, summary.marketingModel != summary.modelName {
                    Text(summary.modelName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(summary?.systemVersion ?? "macOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var placeholderCard: some View {
        SystemSpecCard(
            symbolName: "circle.fill",
            title: "Loading",
            symbolPrimaryColor: .secondary,
            symbolSecondaryColor: .secondary
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Placeholder")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Placeholder detail")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func specCard(
        title: String,
        symbolName: String,
        symbolPrimaryColor: Color,
        symbolSecondaryColor: Color,
        primaryValue: String,
        secondaryValue: String? = nil
    ) -> some View {
        SystemSpecCard(
            symbolName: symbolName,
            title: title,
            symbolPrimaryColor: symbolPrimaryColor,
            symbolSecondaryColor: symbolSecondaryColor
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(primaryValue)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                if let secondaryValue, !secondaryValue.isEmpty {
                    Text(secondaryValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func storageCard(summary: MachineSummary) -> some View {
        let snapshot = summary.storageSnapshot ?? StorageSnapshot(
            totalBytes: summary.storageTotalBytes,
            availableBytes: summary.storageAvailableBytes
        )
        let totalBytes = max(snapshot.totalBytes, 0)
        let availableBytes = max(snapshot.availableBytes, 0)
        let usedBytes = max(totalBytes - availableBytes, 0)
        let progress = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0

        return SystemSpecCard(
            symbolName: "internaldrive.fill",
            title: localizer.text(.systemLabelStorage),
            symbolPrimaryColor: .mint,
            symbolSecondaryColor: .blue
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(formatter.storageSummary(totalBytes: snapshot.totalBytes, availableBytes: snapshot.availableBytes))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                StorageUsageBar(progress: progress)

                HStack {
                    Text(byteCountString(availableBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(byteCountString(usedBytes) + " used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func batteryCard(summary: MachineSummary) -> some View {
        let battery = summary.battery
        let chargeValue = battery.flatMap { batteryPercent(from: $0.chargePercent) }
        let chargeColor = batteryColor(for: chargeValue)

        return SystemSpecCard(
            symbolName: "battery.100percent",
            title: localizer.text(.systemLabelBattery),
            symbolPrimaryColor: .green,
            symbolSecondaryColor: .yellow
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(battery?.chargePercent ?? localizer.text(.unavailable))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(chargeColor)

                if let condition = battery?.condition, !condition.isEmpty {
                    Text(condition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let powerSource = battery?.powerSource, !powerSource.isEmpty {
                    Text(powerSource)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(localizer.text(.unavailable))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
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

private struct SystemSpecCard<Content: View>: View {
    let symbolName: String
    let title: String
    let symbolPrimaryColor: Color
    let symbolSecondaryColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(symbolPrimaryColor, symbolSecondaryColor)
                    .frame(width: 30, height: 30)
                    .background(.quaternary.opacity(0.8), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
