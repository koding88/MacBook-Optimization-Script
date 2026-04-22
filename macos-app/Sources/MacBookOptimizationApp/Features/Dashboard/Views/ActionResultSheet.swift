import SwiftUI

struct ActionResultSheet: View {
    @EnvironmentObject private var model: OptimizationDashboardViewModel

    let result: PresentedActionResult
    let localizer: AppLocalizer

    @State private var isShowingDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if let summary = result.summary {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(summary.primaryValue)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)

                        if !summary.secondaryValues.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(summary.secondaryValues.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(localizer.text(item.labelKey))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Spacer(minLength: 12)

                                        Text(item.value)
                                            .font(.subheadline.weight(.semibold))
                                            .multilineTextAlignment(.trailing)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                } label: {
                    Text(localizer.text(.detailSummary))
                        .font(.headline)
                }
            }

            if let details = visibleDetails {
                if result.summary == nil {
                    detailsPanel(details)
                } else {
                    DisclosureGroup(localizer.text(.resultDialogDetailsTitle), isExpanded: $isShowingDetails) {
                        detailsScrollView(details)
                            .padding(.top, 12)
                    }
                    .controlSize(.large)
                }
            }

            HStack {
                Spacer()

                Button(localizer.text(.done)) {
                    model.dismissPresentedActionResult()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 320)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: result.symbolName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tintColor)
                .frame(width: 56, height: 56)
                .background(tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(result.title)
                    .font(.title2.weight(.semibold))

                Text(result.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var visibleDetails: String? {
        guard let details = result.details?.trimmingCharacters(in: .whitespacesAndNewlines),
              !details.isEmpty else {
            return nil
        }
        return details
    }

    private func detailsPanel(_ details: String) -> some View {
        GroupBox {
            detailsScrollView(details)
                .padding(16)
        } label: {
            Text(localizer.text(.resultDialogDetailsTitle))
                .font(.headline)
        }
    }

    private func detailsScrollView(_ details: String) -> some View {
        ScrollView {
            Text(details)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(minHeight: 140, maxHeight: 240)
    }

    private var tintColor: Color {
        switch result.kind {
        case .success:
            return .green
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
