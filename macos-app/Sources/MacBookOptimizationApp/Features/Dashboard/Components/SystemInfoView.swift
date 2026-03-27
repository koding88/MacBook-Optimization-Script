import SwiftUI

struct SystemInfoView: View {
    let summary: MachineSummary?
    let localizer: AppLocalizer

    private var formatter: SystemInfoFormatter {
        SystemInfoFormatter(localizer: localizer)
    }

    struct DetailRow: Equatable {
        let label: String
        let value: String
        let secondaryValue: String?
    }

    var detailRows: [DetailRow] {
        guard let summary else { return [] }

        var rows = [
            DetailRow(label: localizer.text(.systemLabelChip), value: summary.chipName, secondaryValue: nil)
        ]

        if let coreDescription = summary.coreDescription {
            rows.append(DetailRow(label: localizer.text(.systemLabelCPU), value: coreDescription, secondaryValue: nil))
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
        Section {
            if let summary {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)
                            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.marketingModel)
                                .font(.title2)
                            if summary.marketingModel != summary.modelName {
                                Text(summary.modelName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(summary.systemVersion)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    GroupBox {
                        ForEach(Array(detailRows.enumerated()), id: \.offset) { _, row in
                            LabeledContent(row.label, value: row.value)
                            if let secondaryValue = row.secondaryValue {
                                Text(secondaryValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        } header: {
            Text(localizer.text(.summaryTitle))
        }
    }
}
