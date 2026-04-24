import SwiftUI

struct GPUSnapshotView: View {
    @ObservedObject var viewModel: GPUSnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel

    private let cardCornerRadius: CGFloat = 12
    private let miniCardCornerRadius: CGFloat = 10

    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }

    private var displayMetrics: GPUSnapshotMetrics? {
        viewModel.currentMetrics
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                if let error = viewModel.error {
                    errorState(error)
                } else if let metrics = displayMetrics {
                    overviewCard(metrics: metrics)
                    liveTelemetryCard(metrics: metrics)
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
                        viewModel.refresh()
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

    private func liveTelemetryCard(metrics: GPUSnapshotMetrics) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: localizer.text(.gpuSnapshotLiveTitle),
                    subtitle: metrics.liveTelemetry.title
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        unavailableMetricCard(localizer.text(.gpuSnapshotTelemetryUsageTitle))
                        unavailableMetricCard(localizer.text(.gpuSnapshotTelemetryFrequencyTitle))
                        unavailableMetricCard(localizer.text(.gpuSnapshotTelemetryMemoryTitle))
                        unavailableMetricCard(localizer.text(.gpuSnapshotTelemetryPowerTitle))
                    }

                    VStack(spacing: 10) {
                        unavailableMetricRow(localizer.text(.gpuSnapshotTelemetryUsageTitle))
                        unavailableMetricRow(localizer.text(.gpuSnapshotTelemetryFrequencyTitle))
                        unavailableMetricRow(localizer.text(.gpuSnapshotTelemetryMemoryTitle))
                        unavailableMetricRow(localizer.text(.gpuSnapshotTelemetryPowerTitle))
                    }
                }

                Text(metrics.liveTelemetry.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private func unavailableMetricRow(_ title: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(localizer.text(.unavailable))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer(minLength: 0)
        }
    }

    private func unavailableMetricCard(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(localizer.text(.unavailable))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
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
        let title = localizer.text(.gpuSnapshotStaticLabel)
        return Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .foregroundStyle(.secondary)
    }
}

private extension GPUSnapshotView {
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
