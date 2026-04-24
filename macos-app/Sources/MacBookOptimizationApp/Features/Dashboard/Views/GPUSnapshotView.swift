import SwiftUI

struct GPUSnapshotView: View {
    @ObservedObject var viewModel: GPUSnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel

    private let cardCornerRadius: CGFloat = 12
    private let miniCardCornerRadius: CGFloat = 10
    private let advancedLoadingBlur: CGFloat = 5.5

    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }

    private var displayMetrics: GPUSnapshotMetrics? {
        viewModel.currentMetrics
    }

    private var shouldBlurAdvancedContent: Bool {
        viewModel.currentMetrics?.gpuMetrics.metrics == nil
    }

    private var advancedOverlayTitle: String {
        if let detail = displayMetrics?.gpuMetrics.detail {
            return advancedStatusText(for: detail)
        }

        switch viewModel.advancedState {
        case .idle:
            return localizer.text(.gpuSnapshotAdvancedIdle)
        case .requestingAuthorization:
            return localizer.text(.gpuSnapshotAdvancedRequestingAuthorization)
        case .running:
            return viewModel.isWaitingForFirstAdvancedSample
                ? localizer.text(.gpuSnapshotAdvancedWaitingForFirstSample)
                : localizer.text(.gpuSnapshotCollecting)
        case .denied:
            return localizer.text(.gpuSnapshotAdvancedDenied)
        case .failed(let message):
            return message
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                if let error = viewModel.error {
                    errorState(error)
                } else if let metrics = displayMetrics {
                    overviewCard(metrics: metrics)
                    gpuMetricsCard(metrics: metrics)
                    displayCard(metrics: metrics)
                } else {
                    ProgressView(localizer.text(.gpuSnapshotCollecting))
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding()
        }
        .onAppear {
            if viewModel.monitoringState == .notStarted {
                viewModel.startMonitoring()
            } else if viewModel.monitoringState == .paused {
                viewModel.resumeMonitoring()
            }
        }
        .onDisappear {
            if viewModel.monitoringState == .running {
                viewModel.pauseMonitoring()
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.16))
                            .frame(width: 36, height: 36)
                        Image(systemName: "display.2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizer.text(.gpuSnapshotTitle))
                            .font(.title2.weight(.semibold))

                        Text(headerSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        if viewModel.advancedState == .running || viewModel.isWaitingForFirstAdvancedSample {
                            viewModel.refreshAdvancedMetrics()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Text("\(localizer.text(.gpuSnapshotAutoRefresh)):")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.refreshInterval },
                            set: { viewModel.updateRefreshInterval($0) }
                        )
                    ) {
                        ForEach(GPUSnapshotViewModel.RefreshInterval.allCases) { interval in
                            Text(localizer.text(interval.localizationKey)).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                headerStatusBadge
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private func overviewCard(metrics: GPUSnapshotMetrics) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: localizer.text(.gpuSnapshotCapabilitiesTitle),
                    subtitle: headerSubtitle
                )

                ForEach(metrics.devices) { device in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)
                            }

                            Spacer()

                            statusBadge(title: "\(device.displayCount) \(localizer.text(.gpuSnapshotDisplays).lowercased())")
                        }

                        capabilityCardGrid(device: device)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                }
            }
        }
    }

    private func gpuMetricsCard(metrics: GPUSnapshotMetrics) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.text(.gpuSnapshotLiveTitle))
                            .font(.headline)
                    }

                    Spacer(minLength: 16)

                    if viewModel.advancedState != .running {
                        Button(localizer.text(.gpuSnapshotAdvancedShowButton)) {
                            viewModel.startAdvancedMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if case .failed(let message) = viewModel.advancedState {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(localizer.text(.gpuSnapshotAdvancedFailed))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                gpuMetricsGrid(metrics.gpuMetrics.metrics)
                    .blur(radius: shouldBlurAdvancedContent ? advancedLoadingBlur : 0)
                    .allowsHitTesting(!shouldBlurAdvancedContent)
                    .overlay {
                        if shouldBlurAdvancedContent {
                            advancedWaitingOverlay
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.24), value: shouldBlurAdvancedContent)
            }
        }
    }

    private func displayCard(metrics: GPUSnapshotMetrics) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: localizer.text(.gpuSnapshotDisplaysTitle),
                    subtitle: localizer.text(.gpuSnapshotDisplaysDescription)
                )

                if metrics.displays.isEmpty {
                    Text(localizer.text(.gpuSnapshotNoDisplays))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(metrics.displays) { display in
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: display.isMain ? "display" : "display.2")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(display.isOnline ? .blue : .secondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(display.name)
                                        .font(.subheadline.weight(.semibold))
                                    
                                    Text(compactDisplayInfo(display))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 6) {
                                    if display.isMain {
                                        primaryBadge(title: localizer.text(.gpuSnapshotDisplayMain))
                                    }
                                    if display.supportsHDR == true {
                                        secondaryBadge(title: localizer.text(.gpuSnapshotDisplayHDR))
                                    }
                                    if display.supportsProMotion == true {
                                        secondaryBadge(title: localizer.text(.gpuSnapshotDisplayProMotion))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
    
    private func compactDisplayInfo(_ display: GPUSnapshotMetrics.DisplaySummary) -> String {
        var parts: [String] = []
        
        if let resolution = display.resolution {
            parts.append(resolution)
        }
        if let refreshRate = display.refreshRate {
            parts.append(refreshRate)
        }
        if let scaleDescription = display.scaleDescription {
            parts.append(scaleDescription)
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func primaryBadge(title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.blue.opacity(0.15)))
            .foregroundStyle(.blue)
    }
    
    private func secondaryBadge(title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.08)))
            .foregroundStyle(.secondary)
    }

    private func capabilityCardGrid(device: GPUSnapshotMetrics.DeviceSummary) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
        
        return LazyVGrid(columns: columns, spacing: 10) {
            capabilityCard(
                icon: "cpu.fill",
                title: localizer.text(.gpuSnapshotMetalSupport),
                value: device.metalSupport ?? localizer.text(.unavailable),
                color: .blue
            )
            
            capabilityCard(
                icon: "memorychip.fill",
                title: localizer.text(.gpuSnapshotUnifiedMemory),
                value: boolText(device.hasUnifiedMemory),
                color: .teal
            )
            
            capabilityCard(
                icon: "square.stack.3d.up.fill",
                title: localizer.text(.gpuSnapshotWorkingSet),
                value: device.recommendedMaxWorkingSetSizeBytes.map(GPUSnapshotFormatting.byteString) ?? localizer.text(.unavailable),
                color: .purple
            )
            
            capabilityCard(
                icon: "square.grid.3x3.fill",
                title: localizer.text(.gpuSnapshotFamilies),
                value: device.supportedFamilies.isEmpty ? localizer.text(.unavailable) : "\(device.supportedFamilies.count) families",
                color: .orange
            )
        }
    }
    
    private func capabilityCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                    .frame(width: 16)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    private func metricValueCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func boolText(_ value: Bool?) -> String {
        guard let value else { return localizer.text(.unavailable) }
        return value ? localizer.text(.commonYes) : localizer.text(.commonNo)
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value)
    }

    private func megahertzText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value) MHz"
    }

    private func milliwattsText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value) mW"
    }

    private func statusBadge(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    private var headerSubtitle: String {
        guard let metrics = displayMetrics, let firstDevice = metrics.devices.first else {
            return localizer.text(.gpuSnapshotCollecting)
        }

        if let metalSupport = firstDevice.metalSupport {
            return "\(firstDevice.name) • \(metalSupport)"
        }
        return firstDevice.name
    }

    private var headerStatusBadge: some View {
        let title = viewModel.advancedState == .running ? localizer.text(.commonLive) : localizer.text(.gpuSnapshotStaticLabel)
        return Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .foregroundStyle(.secondary)
    }

    private func advancedStatusText(for detail: String) -> String {
        switch detail {
        case "requestingAuthorization":
            return localizer.text(.gpuSnapshotAdvancedRequestingAuthorization)
        case "waitingForFirstSample":
            return localizer.text(.gpuSnapshotAdvancedWaitingForFirstSample)
        case "denied":
            return localizer.text(.gpuSnapshotAdvancedDenied)
        default:
            return detail
        }
    }
}

private extension GPUSnapshotView {
    func gpuMetricsGrid(_ metrics: GPUMetrics?) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            metricCardWithBar(
                title: localizer.text(.gpuSnapshotTelemetryUsageTitle),
                value: percentText(metrics?.usagePercent),
                progress: (metrics?.usagePercent ?? 0) / 100,
                color: usageColor(metrics?.usagePercent ?? 0)
            )
            
            metricCardWithScale(
                title: localizer.text(.gpuSnapshotTelemetryFrequencyTitle),
                value: megahertzText(metrics?.frequencyMHz),
                color: .blue
            )
            
            metricCardWithScale(
                title: localizer.text(.gpuSnapshotTelemetryPowerTitle),
                value: milliwattsText(metrics?.powerMilliwatts),
                color: .orange
            )
        }
    }
    
    func metricCardWithBar(title: String, value: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.12))
                    
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.75))
                        .frame(width: geometry.size.width * max(0, min(progress, 1)))
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    func metricCardWithScale(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color.opacity(0.15 + Double(index) * 0.15))
                        .frame(height: 8)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    func usageColor(_ usage: Double) -> Color {
        if usage < 50 { return .green }
        if usage < 75 { return .yellow }
        return .orange
    }

    func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    func metricPill(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
    }

    func innerMetricSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    var advancedStatusMessage: some View {
        Group {
            switch viewModel.advancedState {
            case .failed:
                EmptyView()
            default:
                EmptyView()
            }
        }
    }

    var advancedWaitingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.42))

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(advancedOverlayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .padding(18)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    func errorState(_ message: String) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(localizer.text(.gpuSnapshotFailed))
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
