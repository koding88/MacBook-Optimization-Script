import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    private var localizer: AppLocalizer {
        AppLocalizer(language: settings.language)
    }

    private var formatter: SettingsFormatter {
        SettingsFormatter(localizer: localizer)
    }

    var body: some View {
        Form {
            Section(localizer.text(.languageSection)) {
                Picker(localizer.text(.languageLabel), selection: $settings.language) {
                    Text(localizer.text(.englishLanguage)).tag(AppLanguage.english)
                    Text(localizer.text(.vietnameseLanguage)).tag(AppLanguage.vietnamese)
                }
                .pickerStyle(.menu)
            }

            Section(localizer.text(.refreshSection)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(localizer.text(.refreshIntervalLabel))
                        Spacer()
                        Text(formatter.autoRefreshDescription(minutes: settings.refreshIntervalMinutes))
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(settings.refreshIntervalMinutes) },
                            set: { settings.refreshIntervalMinutes = Int($0.rounded()) }
                        ),
                        in: 0 ... 60,
                        step: 1
                    )
                }

                Toggle(localizer.text(.showInspectorLabel), isOn: $settings.showInspectorPanel)
            }

            Section(localizer.text(.safetySection)) {
                Toggle(localizer.text(.confirmPrivilegedLabel), isOn: $settings.confirmPrivilegedActions)

                Picker(localizer.text(.rowDensityLabel), selection: $settings.rowDensity) {
                    Text(localizer.text(.rowDensityComfortable)).tag(RowDensity.comfortable)
                    Text(localizer.text(.rowDensityCompact)).tag(RowDensity.compact)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .frame(width: 460)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(localizer.text(.done)) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
