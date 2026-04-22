import SwiftUI

struct ActivityFeedView: View {
    let localizer: AppLocalizer
    @Binding var filter: OptimizationDashboardViewModel.ActivityTimeFilter
    let items: [ActivityItem]
    let onDelete: (ActivityItem.ID) -> Void
    let onClearAll: () -> Void

    var body: some View {
        List {
            Section {
                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(localizer.text(.activityTitle))
                            .font(.headline)
                        Text(localizer.text(.noLogsYet))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                } else {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.symbolName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(color(for: item.kind))
                                .frame(width: 36, height: 36)
                                .background(color(for: item.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(item.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Spacer(minLength: 8)
                                    Text(item.date, format: .dateTime.hour().minute())
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                }

                                Text(item.message)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer(minLength: 8)

                            Button(role: .destructive) {
                                onDelete(item.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .help(localizer.text(.activityDelete))
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(localizer.text(.activityTitle))
        .toolbar {
            ToolbarItem {
                Picker(localizer.text(.activityFilterLabel), selection: $filter) {
                    ForEach(OptimizationDashboardViewModel.ActivityTimeFilter.allCases) { option in
                        Text(title(for: option)).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .help(localizer.text(.activityFilterHelp))
            }

            ToolbarItem {
                Button(localizer.text(.activityClearAll)) {
                    onClearAll()
                }
                .disabled(items.isEmpty)
            }
        }
    }

    private func title(for option: OptimizationDashboardViewModel.ActivityTimeFilter) -> String {
        switch option {
        case .last5Minutes:
            return localizer.text(.activityFilterLast5Minutes)
        case .all:
            return localizer.text(.activityFilterAll)
        case .lastHour:
            return localizer.text(.activityFilterLastHour)
        case .today:
            return localizer.text(.activityFilterToday)
        }
    }

    private func color(for kind: ActivityKind) -> Color {
        switch kind {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }
}
