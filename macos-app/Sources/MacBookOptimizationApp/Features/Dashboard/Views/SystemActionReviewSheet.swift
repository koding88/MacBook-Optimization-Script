import SwiftUI

struct SystemActionReviewSheet: View {
    @EnvironmentObject private var model: OptimizationDashboardViewModel

    let review: SystemActionReviewPlan
    let localizer: AppLocalizer

    private var currentReview: SystemActionReviewPlan {
        model.pendingSystemActionReview ?? review
    }

    private var selectionProgress: Double {
        guard !currentReview.steps.isEmpty else { return 0 }
        return Double(currentReview.selectedCount) / Double(currentReview.steps.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(currentReview.mode == .run ? localizer.text(.systemReviewTitle) : localizer.string(currentReview.action.titleKey))
                    .font(.title2.weight(.semibold))

                Text(
                    currentReview.mode == .run
                        ? localizer.format(.systemReviewMessage, localizer.string(currentReview.action.titleKey))
                        : localizer.text(.restoreReviewMessage)
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(nsColor: .separatorColor).opacity(0.18))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * selectionProgress, selectionProgress > 0 ? 10 : 0))
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(localizer.format(.systemReviewStepCount, currentReview.selectedCount, currentReview.steps.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(selectionProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 10) {
                Button(localizer.text(.systemReviewSelectAll)) {
                    model.selectAllSystemActionReviewSteps()
                }
                .buttonStyle(.bordered)

                Button(localizer.text(.systemReviewClearAll)) {
                    model.clearSystemActionReviewSteps()
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(currentReview.steps) { step in
                        stepRow(step)
                    }
                }
            }
            .frame(minHeight: 280)

            HStack {
                Spacer()

                Button(localizer.text(.cancel), role: .cancel) {
                    model.cancelSystemActionReview()
                }

                Button(localizer.text(currentReview.runButtonTitleKey)) {
                    model.confirmSystemActionReview()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!currentReview.hasSelection)
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 480)
    }

    private func stepRow(_ step: SystemActionReviewStep) -> some View {
        let isSelected = currentReview.selectedStepIDs.contains(step.id)

        return Toggle(isOn: Binding(
            get: { isSelected },
            set: { _ in model.toggleSystemActionReviewStep(id: step.id) }
        )) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(step.title)
                        .font(.headline)

                    if step.requiresAdministrator {
                        Label(localizer.text(.systemReviewAdminBadge), systemImage: "key.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(localizer.text(.systemReviewCommandLabel))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)

                    Text(step.command)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .toggleStyle(.checkbox)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
