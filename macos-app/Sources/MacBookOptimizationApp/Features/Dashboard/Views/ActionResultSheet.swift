import SwiftUI

struct ActionResultSheet: View {
    @EnvironmentObject private var model: OptimizationDashboardViewModel

    let result: PresentedActionResult
    let localizer: AppLocalizer

    @State private var isShowingDetails = false

    private var detailLineCount: Int {
        visibleDetails?.split(whereSeparator: \.isNewline).count ?? 0
    }

    private var sheetWidth: CGFloat {
        switch result.layout {
        case .compact:
            return 460
        case .medium:
            return 620
        case .large:
            return 700
        }
    }

    private var sheetHeight: CGFloat {
        switch result.layout {
        case .compact:
            return 210
        case .medium:
            return 340
        case .large:
            return 470
        }
    }

    private var terminalHeight: CGFloat {
        switch result.layout {
        case .compact:
            return 140
        case .medium:
            return max(180, min(240, CGFloat(max(detailLineCount, 4)) * 18))
        case .large:
            return max(240, min(320, CGFloat(max(detailLineCount, 8)) * 18))
        }
    }

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
                        detailsTerminal(details)
                            .padding(.top, 12)
                    }
                    .controlSize(.large)
                    .animation(.easeInOut(duration: 0.18), value: isShowingDetails)
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
        .frame(width: sheetWidth)
        .frame(minHeight: sheetHeight)
        .onAppear {
            isShowingDetails = result.layout == .large
        }
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
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.text(.resultDialogDetailsTitle))
                .font(.headline)

            detailsTerminal(details)
        }
    }

    private func detailsTerminal(_ details: String) -> some View {
        TerminalSurfaceView(
            title: result.title,
            output: details,
            emptyMessage: localizer.text(.noOutputYet),
            animateKey: result.id.uuidString,
            minHeight: terminalHeight,
            maxHeight: terminalHeight
        )
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
