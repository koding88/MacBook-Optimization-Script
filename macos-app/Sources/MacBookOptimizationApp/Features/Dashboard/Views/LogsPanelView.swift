import SwiftUI

struct LogsPanelView: View {
    let localizer: AppLocalizer
    let output: String

    var body: some View {
        ScrollView {
            Text(output.isEmpty ? localizer.text(.noOutputYet) : output)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle(localizer.text(.logsTitle))
    }
}
