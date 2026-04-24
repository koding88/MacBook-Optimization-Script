import Charts
import SwiftUI

struct CPUSnapshotView: View {
    @ObservedObject var viewModel: CPUSnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel

    private let cardCornerRadius: CGFloat = 12
    private let meterHeight: CGFloat = 12
    private let overallChartHeight: CGFloat = 170
    private let advancedLoadingBlur: CGFloat = 5.5

    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }

    private var displayBasicMetrics: BasicCPUMetrics {
        viewModel.basicMetrics ?? placeholderBasicMetrics
    }

    private var displayAdvancedMetrics: CPUMetrics {
        viewModel.advancedMetrics ?? placeholderAdvancedMetrics
    }

    private var displayCPUUsageChartData: [(Date, Double)] {
        let data = viewModel.cpuUsageChartData
        return data.isEmpty ? placeholderCPUUsageChartData : data
    }

    private var shouldBlurAdvancedContent: Bool {
        viewModel.advancedMetrics == nil
    }

    private var advancedOverlayTitle: String {
        switch viewModel.advancedState {
        case .idle:
            return localizer.text(.cpuSnapshotAdvancedIdle)
        case .requestingAuthorization:
            return localizer.text(.cpuSnapshotAdvancedRequestingAuthorization)
        case .running:
            return localizer.text(.cpuSnapshotCollecting)
        case .denied:
            return localizer.text(.cpuSnapshotAdvancedDenied)
        case .failed(let message):
            return message
        }
    }

    private var overallChartIdentity: String {
        viewModel.advancedMetricsHistory.count >= 2 ? "advanced-overall-chart" : "basic-overall-chart"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                if let error = viewModel.error {
                    errorState(error)
                } else {
                    overallUsageSection(metrics: displayBasicMetrics)
                    advancedDiagnosticsSection
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
                Text(localizer.text(.cpuSnapshotTitle))
                    .font(.title2.weight(.semibold))

                HStack(spacing: 8) {
                    Text(headerCPUName)
                    Text("•")
                    Text(headerCoreCount)
                    Text("•")
                    Text("\(localizer.text(.cpuSnapshotThermal)): \(headerThermalText)")
                        .foregroundStyle(viewModel.basicMetrics == nil ? .secondary : thermalColor(displayBasicMetrics.thermalState))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Text("\(localizer.text(.cpuSnapshotAutoRefresh)):")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.refreshInterval },
                            set: { viewModel.updateRefreshInterval($0) }
                        )
                    ) {
                        ForEach(CPUSnapshotViewModel.RefreshInterval.allCases) { interval in
                            Text(localizer.text(interval.localizationKey)).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                headerStatusBadge
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private func overallUsageSection(metrics: BasicCPUMetrics) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.text(.cpuSnapshotOverallUsage))
                            .font(.headline)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        metricPill(
                            title: localizer.text(.cpuSnapshotThermal),
                            value: displayThermalState(metrics),
                            accent: viewModel.basicMetrics == nil ? .secondary : thermalColor(metrics.thermalState)
                        )

                        metricPill(
                            title: localizer.text(.cpuSnapshotCores),
                            value: coreCountValue(metrics.totalCores),
                            accent: .blue
                        )
                    }
                }

                Chart {
                    ForEach(Array(displayCPUUsageChartData.enumerated()), id: \.offset) { _, item in
                        AreaMark(
                            x: .value("Time", item.0),
                            y: .value("Usage", item.1)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.blue.opacity(viewModel.basicMetrics == nil ? 0.07 : 0.14))

                        LineMark(
                            x: .value("Time", item.0),
                            y: .value("Usage", item.1)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(.init(lineWidth: 2.5, lineCap: .round))
                        .foregroundStyle(Color.blue.opacity(viewModel.basicMetrics == nil ? 0.32 : 0.78))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .frame(height: overallChartHeight)
                .id(overallChartIdentity)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.22), value: overallChartIdentity)
            }
        }
    }

    private var advancedDiagnosticsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.text(.cpuSnapshotAdvancedTitle))
                            .font(.headline)
                        Text(localizer.text(.cpuSnapshotAdvancedDescription))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    if viewModel.advancedState != .running {
                        Button(localizer.text(.cpuSnapshotAdvancedShowButton)) {
                            viewModel.startAdvancedMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                advancedStatusMessage

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        diagnosticsLeftColumn(metrics: displayAdvancedMetrics)
                        diagnosticsRightColumn(metrics: displayAdvancedMetrics)
                    }

                    VStack(spacing: 16) {
                        diagnosticsLeftColumn(metrics: displayAdvancedMetrics)
                        diagnosticsRightColumn(metrics: displayAdvancedMetrics)
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

    private func diagnosticsLeftColumn(metrics: CPUMetrics) -> some View {
        VStack(spacing: 16) {
            summaryInsightsCard(metrics: metrics)
            clusterActivitySection(metrics: metrics)
            coreResidencyBars(metrics: metrics)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func diagnosticsRightColumn(metrics: CPUMetrics) -> some View {
        VStack(spacing: 16) {
            coreFrequencyHeatmap(metrics: metrics)
            frequencyDistributionChart(metrics: metrics)
            powerConsumptionGauges(metrics: metrics)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func summaryInsightsCard(metrics: CPUMetrics) -> some View {
        innerCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.text(.cpuSnapshotAdvancedSummary))
                            .font(.headline)
                        Text(localizer.text(.cpuSnapshotAdvancedSummarySubtitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    metricPill(
                        title: localizer.text(.cpuSnapshotThermal),
                        value: metrics.thermalPressure.displayName,
                        accent: thermalColor(metrics.thermalPressure)
                    )
                }

                HStack(spacing: 12) {
                    statChip(
                        title: localizer.text(.cpuSnapshotOverallUsage),
                        value: percentString(metrics.overallCPUUsage),
                        note: viewModel.advancedMetrics == nil ? localizer.text(.memorySnapshotLoading) : localizer.text(.cpuSnapshotAdvancedLiveSample)
                    )
                    statChip(
                        title: localizer.text(.cpuSnapshotPowerConsumption),
                        value: wattsString(metrics.power.combined),
                        note: viewModel.advancedMetrics == nil ? "—" : localizer.text(.cpuSnapshotAdvancedPackageTotal)
                    )
                }

                VStack(spacing: 10) {
                    ForEach(Array(displayAdvancedInsights(metrics).enumerated()), id: \.offset) { _, insight in
                        insightRow(insight)
                    }
                }
            }
        }
    }

    private func clusterActivitySection(metrics: CPUMetrics) -> some View {
        innerCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: localizer.text(.cpuSnapshotClusterActivity),
                    subtitle: localizer.text(.cpuSnapshotAdvancedClusterSubtitle)
                )

                VStack(spacing: 12) {
                    ForEach(metrics.clusters) { cluster in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(cluster.name)
                                    .font(.subheadline.weight(.medium))

                                Spacer()

                                Text(percentString(cluster.activeResidency))
                                    .font(.title3.weight(.semibold))
                            }

                            standardizedBar(
                                segments: [
                                    .init(value: cluster.activeResidency / 100, color: clusterColor(cluster.name).opacity(0.85)),
                                    .init(value: max(0, 1 - (cluster.activeResidency / 100)), color: clusterColor(cluster.name).opacity(0.18))
                                ]
                            )

                            HStack(spacing: 10) {
                                compactAnnotation(localizer.text(.cpuSnapshotAdvancedFrequencyLabel), value: gigahertzString(cluster.activeFrequency))
                                compactAnnotation(localizer.text(.cpuSnapshotAdvancedOnlineLabel), value: percentString(cluster.online))
                            }
                        }
                    }
                }
            }
        }
    }

    private func coreResidencyBars(metrics: CPUMetrics) -> some View {
        innerCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: localizer.text(.cpuSnapshotCoreResidency),
                    subtitle: localizer.text(.cpuSnapshotAdvancedResidencySubtitle)
                )

                VStack(spacing: 12) {
                    ForEach(metrics.clusters) { cluster in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(cluster.name)
                                    .font(.subheadline.weight(.medium))

                                Spacer()

                                Text(percentString(cluster.activeResidency))
                                    .font(.title3.weight(.semibold))
                            }

                            standardizedBar(
                                segments: [
                                    .init(value: cluster.activeResidency / 100, color: .blue.opacity(0.75)),
                                    .init(value: cluster.idleResidency / 100, color: .teal.opacity(0.45)),
                                    .init(value: cluster.downResidency / 100, color: .gray.opacity(0.35))
                                ]
                            )

                            HStack(spacing: 10) {
                                compactAnnotation(localizer.text(.cpuSnapshotAdvancedActiveShort), value: percentString(cluster.activeResidency))
                                compactAnnotation(localizer.text(.cpuSnapshotAdvancedIdleShort), value: percentString(cluster.idleResidency))
                                compactAnnotation(localizer.text(.cpuSnapshotAdvancedDownShort), value: percentString(cluster.downResidency))
                            }
                        }
                    }
                }
            }
        }
    }

    private func coreFrequencyHeatmap(metrics: CPUMetrics) -> some View {
        innerCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: localizer.text(.cpuSnapshotPerCoreFrequency),
                    subtitle: localizer.text(.cpuSnapshotAdvancedHeatmapSubtitle)
                )

                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(displayCores(metrics)) { core in
                        let intensity = frequencyIntensity(for: core.frequency)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("CPU \(core.id)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(gigahertzString(core.frequency))
                                .font(.headline.weight(.semibold))

                            Text(percentString(core.activeResidency))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.blue.opacity(0.08 + (0.28 * intensity)))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.blue.opacity(0.08 + (0.24 * intensity)), lineWidth: 1)
                        }
                    }
                }

                frequencyLegend
            }
        }
    }

    private var frequencyLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let range = viewModel.observedFrequencyRange {
                HStack {
                    Text(localizer.text(.cpuSnapshotAdvancedFrequencyScale))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(range.lowerBound) MHz - \(range.upperBound) MHz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                ForEach(Array(legendStops.enumerated()), id: \.offset) { index, stop in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.blue.opacity(stop.opacity))
                            .frame(height: 10)
                        Text(stop.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func frequencyDistributionChart(metrics: CPUMetrics) -> some View {
        innerCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: localizer.text(.cpuSnapshotFrequencyDistribution),
                    subtitle: localizer.text(.cpuSnapshotAdvancedDistributionSubtitle)
                )

                let eligibleClusters = metrics.clusters.filter { !$0.frequencyDistribution.isEmpty }

                if !eligibleClusters.isEmpty {
                    Picker(
                        localizer.text(.cpuSnapshotAdvancedClusterPicker),
                        selection: Binding(
                            get: { viewModel.selectedFrequencyClusterID ?? "" },
                            set: { viewModel.selectedFrequencyClusterID = $0 }
                        )
                    ) {
                        ForEach(eligibleClusters) { cluster in
                            Text(cluster.name).tag(cluster.id)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let cluster = selectedFrequencyCluster(from: metrics) {
                        Chart {
                            ForEach(cluster.frequencyDistribution, id: \.frequency) { bucket in
                                BarMark(
                                    x: .value(localizer.text(.cpuSnapshotAdvancedChartFrequencyAxis), bucket.frequency),
                                    y: .value(localizer.text(.cpuSnapshotAdvancedChartPercentAxis), bucket.percentage)
                                )
                                .cornerRadius(4)
                                .foregroundStyle(Color.blue.opacity(0.72))
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                                    .foregroundStyle(Color.secondary.opacity(0.1))
                                AxisValueLabel {
                                    if let frequency = value.as(Int.self) {
                                        Text("\(frequency) MHz")
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                                    .foregroundStyle(Color.secondary.opacity(0.1))
                                AxisValueLabel {
                                    if let percent = value.as(Int.self) {
                                        Text("\(percent)%")
                                    }
                                }
                            }
                        }
                        .frame(height: 200)

                        HStack(spacing: 10) {
                            compactAnnotation(localizer.text(.cpuSnapshotAdvancedChartFrequencyAxis), value: cluster.name)
                            if let peakBucket = cluster.frequencyDistribution.max(by: { $0.percentage < $1.percentage }) {
                                compactAnnotation(localizer.text(.cpuSnapshotAdvancedPeakBucket), value: "\(peakBucket.frequency) MHz")
                            }
                        }
                    } else {
                        chartEmptyState(localizer.text(.cpuSnapshotNoFrequencyDistributionData))
                    }
                } else {
                    chartEmptyState(localizer.text(.cpuSnapshotNoFrequencyDistributionData))
                }
            }
        }
    }

    private func powerConsumptionGauges(metrics: CPUMetrics) -> some View {
        innerCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: localizer.text(.cpuSnapshotPowerConsumption),
                    subtitle: localizer.text(.cpuSnapshotAdvancedPowerSubtitle)
                )

                VStack(spacing: 14) {
                    powerRow(
                        title: "CPU",
                        value: metrics.power.cpu,
                        max: max(metrics.power.combined, 1),
                        color: .blue
                    )
                    powerRow(
                        title: "GPU",
                        value: metrics.power.gpu,
                        max: max(metrics.power.combined, 1),
                        color: .teal
                    )
                    powerRow(
                        title: "ANE",
                        value: metrics.power.ane,
                        max: max(metrics.power.combined, 1),
                        color: .gray
                    )
                    powerRow(
                        title: localizer.text(.cpuSnapshotAdvancedTotalPowerLabel),
                        value: metrics.power.combined,
                        max: max(metrics.power.combined, 1),
                        color: .orange
                    )
                }
            }
        }
    }

    private func powerRow(title: String, value: Int, max maxValue: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(wattsString(value))
                    .font(.title3.weight(.semibold))
            }

            standardizedBar(
                segments: [
                    .init(value: Double(value) / Double(maxValue), color: color.opacity(0.82)),
                    .init(value: Swift.max(0, 1 - (Double(value) / Double(maxValue))), color: color.opacity(0.16))
                ]
            )
        }
    }

    private func statusMessage(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorState(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizer.text(.statusFailed))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private func chartEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private func innerCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func statChip(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func metricPill(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func compactAnnotation(_ title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
    }

    private func insightRow(_ insight: CPUSnapshotViewModel.AdvancedInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(insight.value)
                .font(.title3.weight(.semibold))
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func standardizedBar(segments: [BarSegment]) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: geometry.size.width * max(0, min(segment.value, 1)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: meterHeight / 2, style: .continuous))
        }
        .frame(height: meterHeight)
    }

    private var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var innerCardBackground: some ShapeStyle {
        Color(nsColor: .windowBackgroundColor)
    }

    private var legendStops: [(title: String, opacity: Double)] {
        [
            (localizer.text(.cpuSnapshotAdvancedLegendLow), 0.12),
            (localizer.text(.cpuSnapshotAdvancedLegendMid), 0.2),
            (localizer.text(.cpuSnapshotAdvancedLegendHigh), 0.28),
            (localizer.text(.cpuSnapshotAdvancedLegendPeak), 0.36)
        ]
    }

    private func thermalColor(_ pressure: CPUMetrics.ThermalPressure) -> Color {
        switch pressure {
        case .nominal: return .green
        case .moderate: return .yellow
        case .heavy, .trapping: return .orange
        case .sleeping: return .gray
        }
    }

    private func clusterColor(_ name: String) -> Color {
        if name.contains("E-") { return .teal }
        if name.contains("P0-") { return .blue }
        if name.contains("P1-") { return .indigo }
        return .gray
    }

    private func frequencyIntensity(for frequency: Int) -> Double {
        guard let range = viewModel.observedFrequencyRange, range.lowerBound < range.upperBound else {
            return 0.4
        }

        return Double(frequency - range.lowerBound) / Double(range.upperBound - range.lowerBound)
    }

    private func percentString(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func gigahertzString(_ frequencyInMHz: Int) -> String {
        String(format: "%.2f GHz", Double(frequencyInMHz) / 1000)
    }

    private func wattsString(_ milliwatts: Int) -> String {
        String(format: "%.2f W", Double(milliwatts) / 1000)
    }

    private var headerCPUName: String {
        guard let metrics = viewModel.basicMetrics else {
            return "—"
        }
        return metrics.cpuName
    }

    private var headerCoreCount: String {
        guard let metrics = viewModel.basicMetrics else {
            return "0 \(localizer.text(.cpuSnapshotCores))"
        }
        return "\(metrics.totalCores) \(localizer.text(.cpuSnapshotCores))"
    }

    private var headerThermalText: String {
        guard let metrics = viewModel.basicMetrics else {
            return localizer.text(.memorySnapshotLoading)
        }
        return metrics.thermalState.displayName
    }

    private var headerStatusBadge: some View {
        Group {
            if viewModel.basicMetrics == nil {
                statusCapsule(localizer.text(.memorySnapshotLoading))
            } else if viewModel.monitoringState == .paused {
                statusCapsule(localizer.text(.commonPaused))
            } else {
                statusCapsule(localizer.text(.commonLive))
            }
        }
    }

    private var advancedStatusMessage: some View {
        Group {
            switch viewModel.advancedState {
            case .failed:
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizer.text(.cpuSnapshotAdvancedFailed))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(advancedOverlayTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            default:
                statusMessage(advancedOverlayTitle)
            }
        }
    }

    private var advancedWaitingOverlay: some View {
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

    private func statusCapsule(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.055), in: Capsule())
    }

    private func displayThermalState(_ metrics: BasicCPUMetrics) -> String {
        viewModel.basicMetrics == nil ? "—" : metrics.thermalState.displayName
    }

    private func coreCountValue(_ totalCores: Int) -> String {
        viewModel.basicMetrics == nil ? "0" : "\(totalCores)"
    }

    private var placeholderBasicMetrics: BasicCPUMetrics {
        BasicCPUMetrics(
            timestamp: .now,
            cpuName: "—",
            totalCores: 0,
            overallUsage: 0,
            thermalState: .sleeping
        )
    }

    private var placeholderAdvancedMetrics: CPUMetrics {
        let clusters = [
            CPUMetrics.ClusterMetrics(
                id: "placeholder-e",
                name: "E-Cluster",
                online: 0,
                activeFrequency: 0,
                activeResidency: 0,
                idleResidency: 0,
                downResidency: 100,
                frequencyDistribution: placeholderFrequencyDistribution
            ),
            CPUMetrics.ClusterMetrics(
                id: "placeholder-p0",
                name: "P0-Cluster",
                online: 0,
                activeFrequency: 0,
                activeResidency: 0,
                idleResidency: 0,
                downResidency: 100,
                frequencyDistribution: placeholderFrequencyDistribution
            )
        ]

        let cores = (0..<8).map {
            CPUMetrics.CoreMetrics(id: $0, frequency: 0, activeResidency: 0, idleResidency: 0, downResidency: 100)
        }

        return CPUMetrics(
            timestamp: .now,
            cpuName: "—",
            totalCores: cores.count,
            thermalPressure: .sleeping,
            clusters: clusters,
            cores: cores,
            power: .init(cpu: 0, gpu: 0, ane: 0)
        )
    }

    private var placeholderCPUUsageChartData: [(Date, Double)] {
        let now = Date()
        return stride(from: 4, through: 0, by: -1).map { step in
            (now.addingTimeInterval(TimeInterval(-step * 15)), 0)
        }
    }

    private var placeholderFrequencyDistribution: [CPUMetrics.ClusterMetrics.FrequencyBucket] {
        [
            .init(frequency: 0, percentage: 0),
            .init(frequency: 1000, percentage: 0),
            .init(frequency: 2000, percentage: 0),
            .init(frequency: 3000, percentage: 0)
        ]
    }

    private func displayAdvancedInsights(_ metrics: CPUMetrics) -> [CPUSnapshotViewModel.AdvancedInsight] {
        if viewModel.advancedMetrics != nil {
            return viewModel.advancedInsights
        }

        return [
            .init(title: "Most active cluster", value: "0%", detail: "—"),
            .init(title: "Peak core", value: "0.00 GHz", detail: "—"),
            .init(title: "Power draw", value: "0.00 W", detail: "—")
        ]
    }

    private func displayCores(_ metrics: CPUMetrics) -> [CPUMetrics.CoreMetrics] {
        metrics.cores.isEmpty ? placeholderAdvancedMetrics.cores : metrics.cores
    }

    private func selectedFrequencyCluster(from metrics: CPUMetrics) -> CPUMetrics.ClusterMetrics? {
        if viewModel.advancedMetrics != nil {
            return viewModel.selectedFrequencyCluster
        }

        return metrics.clusters.first
    }

    private struct BarSegment {
        let value: Double
        let color: Color
    }
}
