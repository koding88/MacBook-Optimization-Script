import SwiftUI

struct MDMSnapshotView: View {
    @ObservedObject var viewModel: MDMSnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel
    
    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizer.text(.mdmSnapshotTitle))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let metrics = viewModel.currentMetrics {
                    Text(statusText(metrics.enrollmentStatus))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func statusOverview(metrics: MDMMetrics) -> some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon(metrics.enrollmentStatus))
                .font(.system(size: 32))
                .foregroundStyle(statusColor(metrics.enrollmentStatus))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText(metrics.enrollmentStatus))
                    .font(.headline)
                
                Text(statusDescription(metrics))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func enrollmentCard(metrics: MDMMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localizer.text(.mdmSnapshotEnrollmentStatus))
                    .font(.headline)
                
                Spacer()
                
                statusBadge(
                    text: metrics.mdmEnrolled ? localizer.text(.commonYes) : localizer.text(.commonNo),
                    color: metrics.mdmEnrolled ? .green : .gray
                )
            }
            
            Divider()
            
            infoRow(
                icon: "checkmark.circle",
                title: localizer.text(.mdmSnapshotCurrentEnrollment),
                value: metrics.mdmEnrolled ? localizer.text(.commonYes) : localizer.text(.commonNo),
                valueColor: metrics.mdmEnrolled ? .green : .secondary
            )
            
            infoRow(
                icon: "arrow.down.circle",
                title: localizer.text(.mdmSnapshotEnrolledViaDEP),
                value: metrics.enrolledViaDEP ? localizer.text(.commonYes) : localizer.text(.commonNo),
                valueColor: metrics.enrolledViaDEP ? .green : .secondary
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func depAssignmentCard(metrics: MDMMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localizer.text(.mdmSnapshotDEPAssignment))
                    .font(.headline)
                
                Spacer()
                
                statusBadge(
                    text: metrics.depConfig != nil ? localizer.text(.mdmSnapshotAssigned) : localizer.text(.mdmSnapshotNotAssigned),
                    color: metrics.depConfig != nil ? .orange : .gray
                )
            }
            
            Divider()
            
            if let config = metrics.depConfig {
                infoRow(
                    icon: "building.2",
                    title: localizer.text(.mdmSnapshotOrganization),
                    value: config.organizationName ?? localizer.text(.unavailable),
                    valueColor: .primary
                )
                
                if let url = config.configurationURL {
                    infoRow(
                        icon: "link",
                        title: localizer.text(.mdmSnapshotMDMServer),
                        value: extractDomain(from: url),
                        valueColor: .primary
                    )
                }
            } else {
                Text(localizer.text(.mdmSnapshotNoDEPConfig))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func historicalTracesCard(metrics: MDMMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.text(.mdmSnapshotHistoricalTraces))
                .font(.headline)
            
            Divider()
            
            infoRow(
                icon: metrics.depTracePresent ? "checkmark.circle.fill" : "xmark.circle",
                title: localizer.text(.mdmSnapshotDEPTraces),
                value: metrics.depTracePresent ? localizer.text(.mdmSnapshotPresent) : localizer.text(.mdmSnapshotAbsent),
                valueColor: metrics.depTracePresent ? .orange : .secondary
            )
            
            infoRow(
                icon: metrics.mdmTracePresent ? "checkmark.circle.fill" : "xmark.circle",
                title: localizer.text(.mdmSnapshotMDMTraces),
                value: metrics.mdmTracePresent ? localizer.text(.mdmSnapshotPresent) : localizer.text(.mdmSnapshotAbsent),
                valueColor: metrics.mdmTracePresent ? .orange : .secondary
            )
            
            infoRow(
                icon: metrics.bypassHostsDetected ? "exclamationmark.triangle.fill" : "checkmark.circle",
                title: localizer.text(.mdmSnapshotHostsBypass),
                value: metrics.bypassHostsDetected ? localizer.text(.mdmSnapshotDetected) : localizer.text(.mdmSnapshotNotDetected),
                valueColor: metrics.bypassHostsDetected ? .red : .green
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func depConfigurationCard(config: MDMMetrics.DEPConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.text(.mdmSnapshotDEPConfiguration))
                .font(.headline)
            
            Divider()
            
            if let org = config.organizationName {
                configRow(title: localizer.text(.mdmSnapshotOrganization), value: org)
            }
            
            if let url = config.configurationURL {
                configRow(title: localizer.text(.mdmSnapshotMDMServer), value: extractDomain(from: url))
            }
            
            configRow(
                title: localizer.text(.mdmSnapshotSupervised),
                value: config.isSupervised ? localizer.text(.commonYes) : localizer.text(.commonNo)
            )
            
            configRow(
                title: localizer.text(.mdmSnapshotRemovable),
                value: config.isMDMUnremovable ? localizer.text(.commonNo) : localizer.text(.commonYes)
            )
            
            configRow(
                title: localizer.text(.mdmSnapshotMandatory),
                value: config.isMandatory ? localizer.text(.commonYes) : localizer.text(.commonNo)
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
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        if config.skipSetupItems.count > 10 {
                            Text("+\(config.skipSetupItems.count - 10)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func resetRiskCard(metrics: MDMMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localizer.text(.mdmSnapshotResetRisk))
                    .font(.headline)
                
                Spacer()
                
                statusBadge(
                    text: riskText(metrics.resetRisk),
                    color: riskColor(metrics.resetRisk)
                )
            }
            
            Divider()
            
            Text(riskDescription(metrics))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func infoRow(icon: String, title: String, value: String, valueColor: Color = .primary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(valueColor)
        }
    }
    
    private func configRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
            
            Spacer(minLength: 12)
            
            Text(value)
                .font(.subheadline.weight(.medium))
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
