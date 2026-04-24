import SwiftUI

struct MDMSnapshotView: View {
    @ObservedObject var viewModel: MDMSnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel

    private let cardCornerRadius: CGFloat = 12
    private let statusLoadingBlur: CGFloat = 5.5

    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }

    private var statusDisplayMetrics: MDMMetrics {
        viewModel.currentMetrics ?? placeholderMetrics
    }

    private var shouldBlurStatusContent: Bool {
        viewModel.currentMetrics == nil && viewModel.isLoading
    }

    private var placeholderMetrics: MDMMetrics {
        MDMMetrics(
            timestamp: .now,
            depTracePresent: false,
            mdmTracePresent: false,
            enrolledViaDEP: false,
            mdmEnrolled: false,
            bypassHostsDetected: false,
            depConfig: nil,
            installedProfiles: []
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                if let metrics = viewModel.currentMetrics {
                    statusOverview(metrics: metrics)

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            enrollmentCard(metrics: metrics)
                            depAssignmentCard(metrics: metrics)
                        }

                        VStack(spacing: 16) {
                            enrollmentCard(metrics: metrics)
                            depAssignmentCard(metrics: metrics)
                        }
                    }
                    
                    historicalTracesCard(metrics: metrics)
                    
                    if let config = metrics.depConfig {
                        depConfigurationCard(config: config)
                    }
                    
                    resetRiskCard(metrics: metrics)
                } else if viewModel.isLoading {
                    statusOverview(metrics: statusDisplayMetrics)
                    ProgressView(localizer.text(.mdmSnapshotChecking))
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let error = viewModel.error {
                    errorState(error: error)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .onAppear {
            if viewModel.currentMetrics == nil && !viewModel.isLoading {
                viewModel.refresh()
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(localizer.text(.mdmSnapshotTitle))
                    .font(.title2.weight(.semibold))

                if let metrics = viewModel.currentMetrics {
                    Text(statusText(metrics.enrollmentStatus))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: { viewModel.refresh() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(localizer.text(.mdmSnapshotRefresh))
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private func statusOverview(metrics: MDMMetrics) -> some View {
        snapshotCard {
            HStack(alignment: .top, spacing: 14) {
                statusIconTile(for: metrics.enrollmentStatus)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(statusText(metrics.enrollmentStatus))
                            .font(.headline)

                        statusBadge(
                            text: statusCapsuleText(metrics),
                            color: statusColor(metrics.enrollmentStatus)
                        )
                    }

                    Text(statusDescription(metrics))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .blur(radius: shouldBlurStatusContent ? statusLoadingBlur : 0)
        .overlay {
            if shouldBlurStatusContent {
                loadingOverlay(text: localizer.text(.mdmSnapshotChecking))
            }
        }
    }

    private func enrollmentCard(metrics: MDMMetrics) -> some View {
        snapshotCard {
            HStack(alignment: .top, spacing: 12) {
                sectionHeader(
                    title: localizer.text(.mdmSnapshotEnrollmentStatus),
                    subtitle: enrollmentInsight(metrics)
                )

                Spacer()

                statusBadge(
                    text: metrics.mdmEnrolled ? localizer.text(.commonYes) : localizer.text(.commonNo),
                    color: metrics.mdmEnrolled ? .green : .secondary
                )
            }

            compactInfoRow(
                icon: "checkmark.circle.fill",
                title: localizer.text(.mdmSnapshotCurrentEnrollment),
                value: metrics.mdmEnrolled ? localizer.text(.commonYes) : localizer.text(.commonNo),
                tint: metrics.mdmEnrolled ? .green : .secondary
            )

            compactInfoRow(
                icon: "arrow.down.circle.fill",
                title: localizer.text(.mdmSnapshotEnrolledViaDEP),
                value: metrics.enrolledViaDEP ? localizer.text(.commonYes) : localizer.text(.commonNo),
                tint: metrics.enrolledViaDEP ? .blue : .secondary
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func depAssignmentCard(metrics: MDMMetrics) -> some View {
        snapshotCard {
            HStack(alignment: .top, spacing: 12) {
                sectionHeader(
                    title: localizer.text(.mdmSnapshotDEPAssignment),
                    subtitle: metrics.depConfig != nil
                        ? localizer.text(.mdmSnapshotDEPConfigured)
                        : localizer.text(.mdmSnapshotNoDEPConfig)
                )

                Spacer()

                statusBadge(
                    text: metrics.depConfig != nil ? localizer.text(.mdmSnapshotAssigned) : localizer.text(.mdmSnapshotNotAssigned),
                    color: metrics.depConfig != nil ? .orange : .secondary
                )
            }

            if let config = metrics.depConfig {
                compactInfoRow(
                    icon: "building.2.fill",
                    title: localizer.text(.mdmSnapshotOrganization),
                    value: config.organizationName ?? localizer.text(.unavailable),
                    tint: .orange
                )

                if let url = config.configurationURL {
                    compactInfoRow(
                        icon: "link.circle.fill",
                        title: localizer.text(.mdmSnapshotMDMServer),
                        value: extractDomain(from: url),
                        tint: .blue
                    )
                }
            } else {
                Text(localizer.text(.mdmSnapshotNoDEPConfig))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historicalTracesCard(metrics: MDMMetrics) -> some View {
        snapshotCard {
            sectionHeader(
                title: localizer.text(.mdmSnapshotHistoricalTraces),
                subtitle: localizer.text(.mdmSnapshotHistoricalActivity)
            )

            compactInfoRow(
                icon: metrics.depTracePresent ? "checkmark.circle.fill" : "xmark.circle",
                title: localizer.text(.mdmSnapshotDEPTraces),
                value: metrics.depTracePresent ? localizer.text(.mdmSnapshotPresent) : localizer.text(.mdmSnapshotAbsent),
                tint: metrics.depTracePresent ? .orange : .secondary
            )

            compactInfoRow(
                icon: metrics.mdmTracePresent ? "checkmark.circle.fill" : "xmark.circle",
                title: localizer.text(.mdmSnapshotMDMTraces),
                value: metrics.mdmTracePresent ? localizer.text(.mdmSnapshotPresent) : localizer.text(.mdmSnapshotAbsent),
                tint: metrics.mdmTracePresent ? .orange : .secondary
            )

            compactInfoRow(
                icon: metrics.bypassHostsDetected ? "exclamationmark.triangle.fill" : "checkmark.circle",
                title: localizer.text(.mdmSnapshotHostsBypass),
                value: metrics.bypassHostsDetected ? localizer.text(.mdmSnapshotDetected) : localizer.text(.mdmSnapshotNotDetected),
                tint: metrics.bypassHostsDetected ? .red : .green
            )
        }
    }

    private func depConfigurationCard(config: MDMMetrics.DEPConfiguration) -> some View {
        snapshotCard {
            sectionHeader(
                title: localizer.text(.mdmSnapshotDEPConfiguration),
                subtitle: policyInsight(config)
            )

            configRow(
                title: localizer.text(.mdmSnapshotSupervised),
                value: config.isSupervised ? localizer.text(.commonYes) : localizer.text(.commonNo),
                tint: config.isSupervised ? .green : .secondary
            )

            configRow(
                title: localizer.text(.mdmSnapshotRemovable),
                value: config.isMDMUnremovable ? localizer.text(.commonNo) : localizer.text(.commonYes),
                tint: config.isMDMUnremovable ? .orange : .green
            )

            configRow(
                title: localizer.text(.mdmSnapshotMandatory),
                value: config.isMandatory ? localizer.text(.commonYes) : localizer.text(.commonNo),
                tint: config.isMandatory ? .orange : .secondary
            )

            if !config.skipSetupItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizer.text(.mdmSnapshotSkipSetup))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(config.skipSetupItems.prefix(10), id: \.self) { item in
                            Text(item)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1), in: Capsule())
                                .foregroundStyle(.blue)
                        }

                        if config.skipSetupItems.count > 10 {
                            Text("+\(config.skipSetupItems.count - 10)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func resetRiskCard(metrics: MDMMetrics) -> some View {
        snapshotCard {
            HStack(alignment: .top, spacing: 12) {
                sectionHeader(
                    title: localizer.text(.mdmSnapshotResetRisk),
                    subtitle: riskDescription(metrics)
                )

                Spacer()

                statusBadge(
                    text: riskText(metrics.resetRisk),
                    color: riskColor(metrics.resetRisk)
                )
            }
        }
    }

    private func snapshotCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func compactInfoRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }

            Spacer()
        }
    }

    private func configRow(title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private func statusIconTile(for status: MDMMetrics.EnrollmentStatus) -> some View {
        let tint = statusColor(status)

        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 42, height: 42)

            Image(systemName: statusIcon(status))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private var cardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
    }

    private func loadingOverlay(text: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorState(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            
            Text(localizer.text(.mdmSnapshotNotChecked))
                .font(.headline)
            
            Text(localizer.text(.mdmSnapshotClickToCheck))
                .foregroundStyle(.secondary)
            
            Button(localizer.text(.mdmSnapshotCheckNow)) {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
    
    // Helper functions
    private func statusIcon(_ status: MDMMetrics.EnrollmentStatus) -> String {
        switch status {
        case .enrolled: return "checkmark.circle.fill"
        case .notEnrolled: return "xmark.circle"
        case .depAssignedOnly: return "exclamationmark.triangle.fill"
        case .historicalTracesOnly: return "clock.arrow.circlepath"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private func statusColor(_ status: MDMMetrics.EnrollmentStatus) -> Color {
        switch status {
        case .enrolled: return .green
        case .notEnrolled: return .gray
        case .depAssignedOnly: return .orange
        case .historicalTracesOnly: return .blue
        case .unknown: return .gray
        }
    }
    
    private func statusText(_ status: MDMMetrics.EnrollmentStatus) -> String {
        switch status {
        case .enrolled: return localizer.text(.mdmStatusCurrentlyEnrolled)
        case .notEnrolled: return localizer.text(.mdmStatusNotCurrentlyEnrolled)
        case .depAssignedOnly: return localizer.text(.mdmStatusDepAdeAssigned)
        case .historicalTracesOnly: return localizer.text(.mdmStatusHistoricalTracesFound)
        case .unknown: return localizer.text(.mdmStatusNeedsReview)
        }
    }

    private func statusCapsuleText(_ metrics: MDMMetrics) -> String {
        switch metrics.enrollmentStatus {
        case .enrolled:
            return localizer.text(.commonYes)
        case .depAssignedOnly:
            return localizer.text(.mdmSnapshotAssigned)
        case .historicalTracesOnly:
            return localizer.text(.mdmSnapshotPresent)
        case .notEnrolled:
            return localizer.text(.commonNo)
        case .unknown:
            return localizer.text(.mdmStatusNeedsReview)
        }
    }

    private func statusDescription(_ metrics: MDMMetrics) -> String {
        if metrics.mdmEnrolled {
            return localizer.text(.mdmSnapshotActivelyManaged)
        } else if metrics.depConfig != nil {
            return localizer.text(.mdmSnapshotDEPConfigured)
        } else if metrics.depTracePresent || metrics.mdmTracePresent {
            return localizer.text(.mdmSnapshotHistoricalActivity)
        } else {
            return localizer.text(.mdmSnapshotNoActivity)
        }
    }

    private func enrollmentInsight(_ metrics: MDMMetrics) -> String {
        if metrics.mdmEnrolled {
            return localizer.text(.mdmSnapshotActivelyManaged)
        } else if metrics.enrolledViaDEP {
            return localizer.text(.mdmSnapshotDEPConfigured)
        } else {
            return localizer.text(.mdmSnapshotNoActivity)
        }
    }

    private func policyInsight(_ config: MDMMetrics.DEPConfiguration) -> String {
        if config.isMandatory {
            return localizer.text(.mdmSnapshotDEPConfigured)
        } else if config.isSupervised {
            return localizer.text(.mdmSnapshotActivelyManaged)
        } else {
            return localizer.text(.mdmSnapshotDEPAssignment)
        }
    }

    private func riskText(_ risk: MDMMetrics.ResetRisk) -> String {
        switch risk {
        case .high: return localizer.text(.mdmRiskLikelyYes)
        case .medium: return localizer.text(.mdmRiskPossible)
        case .low: return localizer.text(.mdmRiskUnlikely)
        case .unknown: return localizer.text(.mdmStatusNeedsReview)
        }
    }
    
    private func riskColor(_ risk: MDMMetrics.ResetRisk) -> Color {
        switch risk {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        case .unknown: return .gray
        }
    }
    
    private func riskDescription(_ metrics: MDMMetrics) -> String {
        if metrics.resetRisk == .high {
            return localizer.text(.mdmSnapshotRiskHighDesc)
        } else if metrics.resetRisk == .medium {
            return localizer.text(.mdmSnapshotRiskMediumDesc)
        } else if metrics.resetRisk == .low {
            return localizer.text(.mdmSnapshotRiskLowDesc)
        }
        return localizer.text(.mdmSnapshotRiskUnknownDesc)
    }
    
    private func extractDomain(from url: String) -> String {
        guard let urlObj = URL(string: url),
              let host = urlObj.host else {
            return url
        }
        return host
    }
}

// Simple flow layout for skip setup items
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
