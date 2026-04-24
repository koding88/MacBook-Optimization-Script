import Charts
import SwiftUI

struct MemorySnapshotView: View {
    @ObservedObject var viewModel: MemorySnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel

    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                if let metrics = viewModel.currentMetrics {
                    adaptiveOverview(metrics: metrics)
                    usageBreakdown(metrics: metrics)
                } else if let error = viewModel.error {
                    errorState(error: error)
                } else if viewModel.isMonitoring {
                    ProgressView(localizer.text(.memorySnapshotCollecting))
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    emptyStateView
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizer.text(.memorySnapshotTitle))
                    .font(.title2)
                    .fontWeight(.semibold)

                if let metrics = viewModel.currentMetrics {
                    Text("\(MemoryMetrics.format(bytes: metrics.usedBytes)) / \(MemoryMetrics.format(bytes: metrics.totalBytes)) \(localizer.text(.commonUsed))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text("\(localizer.text(.memorySnapshotAutoRefresh)):")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $viewModel.refreshInterval) {
                    ForEach(MemorySnapshotViewModel.RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .onChange(of: viewModel.refreshInterval) { newValue in
                    viewModel.updateRefreshInterval(newValue)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func adaptiveOverview(metrics: MemoryMetrics) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                pressureCard(metrics: metrics)
                detailsCard(metrics: metrics)
            }

            VStack(spacing: 16) {
                pressureCard(metrics: metrics)
                detailsCard(metrics: metrics)
            }
        }
    }

    private func pressureCard(metrics: MemoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localizer.text(.memorySnapshotPressure))
                    .font(.headline)

                Spacer()

                Text(pressureDisplayName(metrics.pressureLevel))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(pressureColor(metrics.pressureLevel).opacity(0.12), in: Capsule())
                    .foregroundStyle(pressureColor(metrics.pressureLevel))
            }

            if viewModel.pressureHistory.count >= 2 {
                Chart {
                    ForEach(Array(viewModel.pressureHistory.enumerated()), id: \.offset) { _, item in
                        AreaMark(
                            x: .value("Time", item.0),
                            y: .value("Pressure", item.1)
                        )
                        .foregroundStyle(pressureColor(metrics.pressureLevel).opacity(0.16))

                        LineMark(
                            x: .value("Time", item.0),
                            y: .value("Pressure", item.1)
                        )
                        .foregroundStyle(pressureColor(metrics.pressureLevel))
                        .lineStyle(.init(lineWidth: 2.5, lineCap: .round))
                    }
                }
                .chartYScale(domain: 0...1)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                    }
                }
                .frame(height: 140)
            } else {
                memoryPressureBand(metrics: metrics)
            }

            HStack(spacing: 12) {
                statChip(title: localizer.text(.memorySnapshotMemoryUsed), value: MemoryMetrics.format(bytes: metrics.usedBytes))
                statChip(title: localizer.text(.memorySnapshotCachedFiles), value: MemoryMetrics.format(bytes: metrics.cachedBytes))
                statChip(title: localizer.text(.memorySnapshotSwapUsed), value: MemoryMetrics.format(bytes: metrics.swapUsedBytes))
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailsCard(metrics: MemoryMetrics) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 12) {
                    metricRow(localizer.text(.memorySnapshotPhysicalMemory), MemoryMetrics.format(bytes: metrics.totalBytes))
                    metricRow(localizer.text(.memorySnapshotMemoryUsed), MemoryMetrics.format(bytes: metrics.usedBytes))
                    metricRow(localizer.text(.memorySnapshotCachedFiles), MemoryMetrics.format(bytes: metrics.cachedBytes))
                    metricRow(localizer.text(.memorySnapshotSwapUsed), MemoryMetrics.format(bytes: metrics.swapUsedBytes))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(spacing: 12) {
                    metricRow(localizer.text(.memorySnapshotAppMemory), MemoryMetrics.format(bytes: metrics.appBytes))
                    metricRow(localizer.text(.memorySnapshotWiredMemory), MemoryMetrics.format(bytes: metrics.wiredBytes))
                    metricRow(localizer.text(.memorySnapshotCompressed), MemoryMetrics.format(bytes: metrics.compressedBytes))
                    metricRow(localizer.text(.memorySnapshotFreeMemory), MemoryMetrics.format(bytes: metrics.freeBytes))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func memoryPressureBand(metrics: MemoryMetrics) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.12))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                pressureColor(metrics.pressureLevel).opacity(0.35),
                                pressureColor(metrics.pressureLevel).opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * max(metrics.pressureScore, 0.12))
            }
            .overlay(alignment: .leading) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pressureColor(metrics.pressureLevel))
                        .frame(width: 8, height: 8)
                    Text(pressureHint(metrics))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(height: 34)
    }

    private func usageBreakdown(metrics: MemoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.text(.memorySnapshotUsageBreakdown))
                .font(.headline)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    usageSegment(color: .blue, width: geometry.size.width * metrics.usedRatio * (metrics.appBytes > 0 ? Double(metrics.appBytes) / Double(max(metrics.usedBytes, 1)) : 0))
                    usageSegment(color: .orange, width: geometry.size.width * metrics.usedRatio * (metrics.wiredBytes > 0 ? Double(metrics.wiredBytes) / Double(max(metrics.usedBytes, 1)) : 0))
                    usageSegment(color: .purple, width: geometry.size.width * metrics.usedRatio * (metrics.compressedBytes > 0 ? Double(metrics.compressedBytes) / Double(max(metrics.usedBytes, 1)) : 0))
                    usageSegment(color: .green, width: geometry.size.width * metrics.cachedRatio)
                    usageSegment(color: .gray.opacity(0.28), width: geometry.size.width * metrics.freeRatio)
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .frame(height: 18)

            VStack(spacing: 10) {
                legendRow(color: .blue, title: localizer.text(.memorySnapshotAppMemory), value: MemoryMetrics.format(bytes: metrics.appBytes))
                legendRow(color: .orange, title: localizer.text(.memorySnapshotWiredMemory), value: MemoryMetrics.format(bytes: metrics.wiredBytes))
                legendRow(color: .purple, title: localizer.text(.memorySnapshotCompressed), value: MemoryMetrics.format(bytes: metrics.compressedBytes))
                legendRow(color: .green, title: localizer.text(.memorySnapshotCachedFiles), value: MemoryMetrics.format(bytes: metrics.cachedBytes))
                legendRow(color: .gray, title: localizer.text(.memorySnapshotFreeMemory), value: MemoryMetrics.format(bytes: metrics.freeBytes))
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body)

            Spacer(minLength: 12)

            Text(value)
                .font(.body.weight(.semibold))
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func usageSegment(color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(width, 0))
    }

    private func legendRow(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
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
            Image(systemName: "memorychip")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(localizer.text(.memorySnapshotNotStarted))
                .font(.headline)

            Text(localizer.text(.memorySnapshotClickToStart))
                .foregroundStyle(.secondary)

            Button(localizer.text(.memorySnapshotStartMonitoring)) {
                viewModel.startMonitoring()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func pressureDisplayName(_ level: MemoryMetrics.PressureLevel) -> String {
        switch level {
        case .normal:
            return localizer.text(.memorySnapshotPressureNormal)
        case .elevated:
            return localizer.text(.memorySnapshotPressureElevated)
        case .critical:
            return localizer.text(.memorySnapshotPressureCritical)
        }
    }

    private func pressureColor(_ level: MemoryMetrics.PressureLevel) -> Color {
        switch level {
        case .normal:
            return .green
        case .elevated:
            return .orange
        case .critical:
            return .red
        }
    }

    private func pressureHint(_ metrics: MemoryMetrics) -> String {
        switch metrics.pressureLevel {
        case .normal:
            return localizer.text(.memorySnapshotPressureHintNormal)
        case .elevated:
            return localizer.text(.memorySnapshotPressureHintElevated)
        case .critical:
            return localizer.text(.memorySnapshotPressureHintCritical)
        }
    }
}
