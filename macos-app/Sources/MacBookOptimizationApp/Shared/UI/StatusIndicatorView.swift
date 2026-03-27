import SwiftUI

struct StatusIndicatorView: View {
    let status: ActionStatus
    let localizer: AppLocalizer

    var body: some View {
        HStack(spacing: 6) {
            switch status {
            case .ready:
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
            case .enabled:
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red)
            case .needsReview:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            case .running:
                ProgressView()
                    .controlSize(.small)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var label: String {
        switch status {
        case .ready:
            return localizer.text(.statusReady)
        case .enabled:
            return localizer.text(.statusEnabled)
        case .failed:
            return localizer.text(.statusFailed)
        case .needsReview:
            return localizer.text(.statusNeedsReview)
        case .running:
            return localizer.text(.statusRunning)
        }
    }
}
