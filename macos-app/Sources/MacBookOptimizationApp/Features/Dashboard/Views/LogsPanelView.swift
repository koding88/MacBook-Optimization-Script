import SwiftUI

struct LogsPanelView: View {
    let localizer: AppLocalizer
    let output: String
    let entries: [DebugLogEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizer.text(.logsTitle))
                        .font(.title2.weight(.semibold))

                    Text(entries.isEmpty ? localizer.text(.noOutputYet) : localizer.text(.logsConsoleDescription))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TerminalSurfaceView(
                    title: localizer.text(.logsTitle),
                    output: output,
                    emptyMessage: localizer.text(.noOutputYet),
                    animateKey: entries.last?.id.uuidString ?? "logs-empty",
                    minHeight: 520,
                    maxHeight: nil
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(localizer.text(.logsTitle))
    }
}
