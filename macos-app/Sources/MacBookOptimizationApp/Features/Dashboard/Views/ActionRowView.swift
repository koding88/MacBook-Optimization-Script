import SwiftUI

struct ActionRowMetrics {
    static let `default` = ActionRowMetrics()

    let buttonWidth: CGFloat = 72
    let minimumRowHeight: CGFloat = 86
}

struct ActionRowView: View {
    let action: OptimizationAction
    let isRunning: Bool
    let localizer: AppLocalizer
    let density: RowDensity
    let runAction: () -> Void

    @State private var isHovering = false
    private let metrics = ActionRowMetrics.default

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: action.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.quaternary.opacity(isHovering ? 1.0 : 0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(localizer.string(action.titleKey))
                        .font(.headline)

                    if action.isRisky {
                        Label(localizer.text(.riskyAction), systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(localizer.string(action.descriptionKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    StatusIndicatorView(status: isRunning ? .running : action.status, localizer: localizer)

                    if action.kind.requiresAdministrator {
                        Label(localizer.text(.privileged), systemImage: "key.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if action.requiresRestart {
                        Label(localizer.text(.requiresRestart), systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let lastRun = action.lastRunDescription {
                    Text("\(localizer.text(.lastRun)): \(lastRun)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 12)

            Button(action: runAction) {
                ZStack {
                    Text(localizer.text(.run))
                        .opacity(isRunning ? 0 : 1)

                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: metrics.buttonWidth)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(isRunning)
        }
        .padding(.vertical, density == .comfortable ? 10 : 6)
        .frame(minHeight: metrics.minimumRowHeight, alignment: .center)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
    }
}

private extension ActionKind {
    var requiresAdministrator: Bool {
        switch self {
        case .command(let commands):
            return commands.contains(where: \.requiresAdministrator)
        case .dynamic:
            return true
        case .manual, .statuses:
            return false
        }
    }
}
