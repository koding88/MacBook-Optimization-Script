import SwiftUI
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var model: OptimizationDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    private let refreshOptions = AppSettingsStore.allowedRefreshIntervalMinutes
    private let sectionSpacing: CGFloat = 24
    private let rowSpacing: CGFloat = 12
    private let contentPadding: CGFloat = 32

    private var localizer: AppLocalizer {
        AppLocalizer(language: settings.language)
    }

    private var formatter: SettingsFormatter {
        SettingsFormatter(localizer: localizer)
    }

    private var refreshSelection: Binding<Int> {
        Binding(
            get: { normalizedRefresh(settings.refreshIntervalMinutes) },
            set: { settings.refreshIntervalMinutes = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                settingsSection(localizer.text(.languageSection)) {
                    settingsRow(localizer.text(.languageLabel)) {
                        Picker(localizer.text(.languageLabel), selection: $settings.language) {
                            Text(localizer.text(.englishLanguage)).tag(AppLanguage.english)
                            Text(localizer.text(.vietnameseLanguage)).tag(AppLanguage.vietnamese)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(minWidth: 190, alignment: .trailing)
                    }
                }

                settingsSection(localizer.text(.refreshSection)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(formatter.autoRefreshStatus(minutes: settings.refreshIntervalMinutes))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)

                        Picker(localizer.text(.refreshIntervalLabel), selection: refreshSelection) {
                            ForEach(refreshOptions, id: \.self) { minutes in
                                Text(refreshSegmentTitle(for: minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .tint(.accentColor)
                    }
                }

                settingsSection(localizer.text(.appearanceSection)) {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        settingsRow(localizer.text(.showInspectorLabel)) {
                            Toggle("", isOn: $settings.showInspectorPanel)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        settingsRow(localizer.text(.rowDensityLabel)) {
                            Picker(localizer.text(.rowDensityLabel), selection: $settings.rowDensity) {
                                Text(localizer.text(.rowDensityComfortable)).tag(RowDensity.comfortable)
                                Text(localizer.text(.rowDensityCompact)).tag(RowDensity.compact)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(minWidth: 250)
                            .tint(.accentColor)
                        }
                    }
                }

                settingsSection(localizer.text(.safetySection)) {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        settingsRow(localizer.text(.confirmPrivilegedLabel)) {
                            Toggle("", isOn: $settings.confirmPrivilegedActions)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        Button(localizer.text(.resetDefaultsAllButton)) {
                            dismiss()
                            model.resetAllToDefaults()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack {
                    Spacer()

                    Button(localizer.text(.done)) {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 640, minHeight: 560)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: rowSpacing) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    @ViewBuilder
    private func settingsRow<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 16)

            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func normalizedRefresh(_ minutes: Int) -> Int {
        refreshOptions.min(by: { abs($0 - minutes) < abs($1 - minutes) }) ?? 0
    }

    private func refreshSegmentTitle(for minutes: Int) -> String {
        switch minutes {
        case 0:
            return localizer.text(.refreshManual)
        default:
            return "\(minutes)m"
        }
    }
}
