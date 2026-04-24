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
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)
                            }

                            Spacer()

                            statusBadge(title: "\(device.displayCount) \(localizer.text(.gpuSnapshotDisplays).lowercased())")
                        }

                        capabilityGrid(device: device)
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
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.text(.gpuSnapshotLiveTitle))
                            .font(.headline)
                        Text(localizer.text(.gpuSnapshotAdvancedDescription))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    if viewModel.advancedState != .running {
                        Button(localizer.text(.gpuSnapshotAdvancedShowButton)) {
                            viewModel.startAdvancedMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                advancedStatusMessage

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        gpuMetricsColumn(metrics.gpuMetrics.metrics)
                    }

                    VStack(spacing: 12) {
                        gpuMetricsColumn(metrics.gpuMetrics.metrics)
                    }
                }
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
                    ForEach(metrics.displays) { display in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: display.isMain ? "display" : "display.2")
                                .foregroundStyle(display.isOnline ? .blue : .secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(display.name)
                                    .font(.headline)
                                VStack(alignment: .leading, spacing: 2) {
                                    if let resolution = display.resolution {
                                        Text(resolution)
                                    }
                                    if let refreshRate = display.refreshRate {
                                        Text(refreshRate)
                                    }
                                    if let scaleDescription = display.scaleDescription {
                                        Text(scaleDescription)
                                    }
                                    if let colorDepth = display.colorDepth {
                                        Text(colorDepth)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                statusBadge(title: display.isOnline ? localizer.text(.gpuSnapshotDisplayOnline) : localizer.text(.gpuSnapshotDisplayOffline))
                                if display.isMain {
                                    statusBadge(title: localizer.text(.gpuSnapshotDisplayMain))
                                }
                                if display.supportsHDR == true {
                                    statusBadge(title: localizer.text(.gpuSnapshotDisplayHDR))
                                }
                                if display.supportsProMotion == true {
                                    statusBadge(title: localizer.text(.gpuSnapshotDisplayProMotion))
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func capabilityGrid(device: GPUSnapshotMetrics.DeviceSummary) -> some View {
        VStack(spacing: 12) {
            capabilityRow(localizer.text(.gpuSnapshotMetalSupport), device.metalSupport ?? localizer.text(.unavailable))
            capabilityRow(localizer.text(.gpuSnapshotUnifiedMemory), boolText(device.hasUnifiedMemory))
            capabilityRow(localizer.text(.gpuSnapshotWorkingSet), device.recommendedMaxWorkingSetSizeBytes.map(GPUSnapshotFormatting.byteString) ?? localizer.text(.unavailable))
            capabilityRow(localizer.text(.gpuSnapshotFamilies), device.supportedFamilies.isEmpty ? localizer.text(.unavailable) : device.supportedFamilies.joined(separator: ", "))
        }
    }

    private func capabilityRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 190, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
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

    private func metricWaitingCard(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private func compactMetricLine(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
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

    private var advancedStatusText: String {
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
    func gpuMetricsColumn(_ metrics: GPUMetrics?) -> some View {
        VStack(spacing: 12) {
            metricValueCard(localizer.text(.gpuSnapshotTelemetryUsageTitle), value: percentText(metrics?.usagePercent))
            metricValueCard(localizer.text(.gpuSnapshotTelemetryFrequencyTitle), value: megahertzText(metrics?.frequencyMHz))
            metricValueCard(localizer.text(.gpuSnapshotTelemetryPowerTitle), value: milliwattsText(metrics?.powerMilliwatts))
        }
        .frame(maxWidth: .infinity, alignment: .top)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizer.text(.gpuSnapshotAdvancedFailed))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(advancedStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            default:
                Text(advancedStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
