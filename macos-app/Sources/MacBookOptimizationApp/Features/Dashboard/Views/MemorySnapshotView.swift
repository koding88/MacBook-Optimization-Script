import Charts
import SwiftUI

struct MemorySnapshotView: View {
    @ObservedObject var viewModel: MemorySnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel
    
    private let cardCornerRadius: CGFloat = 12
    private let miniCardCornerRadius: CGFloat = 10
    private let pressureChartHeight: CGFloat = 168
    private let pressureZoneLowerBound: Double = 0.46
    private let pressureZoneMiddleBound: Double = 0.72

    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }

    private var pressureChartPoints: [PressureChartPoint] {
        viewModel.pressureHistory.map { PressureChartPoint(timestamp: $0.0, score: $0.1) }
    }

    private var displayMetrics: MemoryMetrics {
        viewModel.currentMetrics ?? placeholderMetrics
    }

    private var chartPoints: [PressureChartPoint] {
        pressureChartPoints.isEmpty ? placeholderPressureChartPoints : pressureChartPoints
    }

    private var currentPressureAccent: Color {
        pressureAccentColor(for: displayMetrics.pressureLevel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headerSection

                if let error = viewModel.error {
                    errorState(error: error)
                } else {
                    adaptiveOverview(metrics: displayMetrics)
                    usageBreakdown(metrics: displayMetrics)
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
                Text(localizer.text(.memorySnapshotTitle))
                    .font(.title2.weight(.semibold))

                HStack(spacing: 8) {
                    Text(headerUsageText)
                    Text("•")
                    Text(headerPressureText)
                        .foregroundStyle(viewModel.currentMetrics == nil ? .secondary : pressureColor(displayMetrics.pressureLevel))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Text("\(localizer.text(.memorySnapshotAutoRefresh)):")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.refreshInterval },
                            set: { viewModel.updateRefreshInterval($0) }
                        )
                    ) {
                        ForEach(MemorySnapshotViewModel.RefreshInterval.allCases) { interval in
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
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.text(.memorySnapshotPressure))
                            .font(.headline)
                        Text(pressureHint(metrics))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        pressureBadge(for: metrics.pressureLevel)

                        if isPressureStable(for: metrics) {
                            stabilityBadge
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                }

                pressureChart(metrics: metrics)
                pressureZoneScale
                pressureZoneLegend

                HStack(spacing: 12) {
                    quickStatCard(
                        title: localizer.text(.memorySnapshotMemoryUsed),
                        value: memoryValueText(metrics.usedBytes),
                        accent: .primary,
                        tint: .blue
                    )
                    quickStatCard(
                        title: localizer.text(.memorySnapshotCachedFiles),
                        value: memoryValueText(metrics.cachedBytes),
                        accent: .primary,
                        tint: cachedMemoryColor
                    )
                    quickStatCard(
                        title: localizer.text(.memorySnapshotSwapUsed),
                        value: memoryValueText(metrics.swapUsedBytes),
                        accent: metrics.swapUsedBytes > 0 ? .primary : .secondary,
                        tint: metrics.swapUsedBytes > 0 ? pressureAccentColor(for: metrics.pressureLevel) : .secondary
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailsCard(metrics: MemoryMetrics) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: localizer.text(.memorySnapshotUsageBreakdown),
                    subtitle: localizer.text(.memorySnapshotPhysicalMemory)
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        detailSection(
                            title: localizer.text(.memorySnapshotSectionCapacity),
                            rows: [
                                (localizer.text(.memorySnapshotPhysicalMemory), memoryValueText(metrics.totalBytes)),
                                (localizer.text(.memorySnapshotFreeMemory), memoryValueText(metrics.freeBytes))
                            ]
                        )
                        detailSection(
                            title: localizer.text(.memorySnapshotSectionUsage),
                            rows: [
                                (localizer.text(.memorySnapshotMemoryUsed), memoryValueText(metrics.usedBytes)),
                                (localizer.text(.memorySnapshotCachedFiles), memoryValueText(metrics.cachedBytes)),
                                (localizer.text(.memorySnapshotSwapUsed), memoryValueText(metrics.swapUsedBytes))
                            ]
                        )
                        detailSection(
                            title: localizer.text(.memorySnapshotSectionSystem),
                            rows: [
                                (localizer.text(.memorySnapshotAppMemory), memoryValueText(metrics.appBytes)),
                                (localizer.text(.memorySnapshotWiredMemory), memoryValueText(metrics.wiredBytes)),
                                (localizer.text(.memorySnapshotCompressed), memoryValueText(metrics.compressedBytes))
                            ]
                        )
                    }

                    VStack(spacing: 10) {
                        detailSection(
                            title: localizer.text(.memorySnapshotSectionCapacity),
                            rows: [
                                (localizer.text(.memorySnapshotPhysicalMemory), memoryValueText(metrics.totalBytes)),
                                (localizer.text(.memorySnapshotFreeMemory), memoryValueText(metrics.freeBytes))
                            ]
                        )
                        detailSection(
                            title: localizer.text(.memorySnapshotSectionUsage),
                            rows: [
                                (localizer.text(.memorySnapshotMemoryUsed), memoryValueText(metrics.usedBytes)),
                                (localizer.text(.memorySnapshotCachedFiles), memoryValueText(metrics.cachedBytes)),
                                (localizer.text(.memorySnapshotSwapUsed), memoryValueText(metrics.swapUsedBytes))
                            ]
                        )
                        detailSection(
                            title: localizer.text(.memorySnapshotSectionSystem),
                            rows: [
                                (localizer.text(.memorySnapshotAppMemory), memoryValueText(metrics.appBytes)),
                                (localizer.text(.memorySnapshotWiredMemory), memoryValueText(metrics.wiredBytes)),
                                (localizer.text(.memorySnapshotCompressed), memoryValueText(metrics.compressedBytes))
                            ]
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pressureChart(metrics: MemoryMetrics) -> some View {
        let points = chartPoints
        let domain = pressureChartDomain(for: points)
        let tickDates = chartTickDates(for: points, domain: domain)

        return Chart {
            pressureZoneMarks(domain: domain)

            ForEach(points) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    yStart: .value("Baseline", point.baselineScore),
                    yEnd: .value("Pressure", point.chartScore)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            currentPressureAccent.opacity(point.isPlaceholder ? 0.08 : 0.18),
                            currentPressureAccent.opacity(0.02)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Pressure", point.displayScore)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(currentPressureAccent)
                .lineStyle(.init(lineWidth: 2.4, lineCap: .round))
            }

            if let latest = points.last {
                PointMark(
                    x: .value("Time", latest.timestamp),
                    y: .value("Pressure", latest.displayScore)
                )
                .foregroundStyle(currentPressureAccent)
                .symbolSize(28)
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: tickDates) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(Color.secondary.opacity(0.07))
                AxisTick(length: 3)
                    .foregroundStyle(Color.secondary.opacity(0.18))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(chartAxisLabel(for: date))
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(chartBackground(metrics))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(height: pressureChartHeight)
        .animation(.easeInOut(duration: 0.22), value: points)
    }

    private func usageBreakdown(metrics: MemoryMetrics) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    title: localizer.text(.memorySnapshotUsageBreakdown),
                    subtitle: breakdownSubtitle(metrics)
                )

                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        usageSegment(color: .blue, width: geometry.size.width * metrics.usedRatio * (metrics.appBytes > 0 ? Double(metrics.appBytes) / Double(max(metrics.usedBytes, 1)) : 0))
                        usageSegment(color: .orange, width: geometry.size.width * metrics.usedRatio * (metrics.wiredBytes > 0 ? Double(metrics.wiredBytes) / Double(max(metrics.usedBytes, 1)) : 0))
                        usageSegment(color: .purple, width: geometry.size.width * metrics.usedRatio * (metrics.compressedBytes > 0 ? Double(metrics.compressedBytes) / Double(max(metrics.usedBytes, 1)) : 0))
                        usageSegment(color: cachedMemoryColor, width: geometry.size.width * metrics.cachedRatio)
                        usageSegment(color: .gray.opacity(0.22), width: geometry.size.width * metrics.freeRatio)
                    }
                    .padding(3)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(height: 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    legendRow(color: .blue, title: localizer.text(.memorySnapshotAppMemory), value: memoryValueText(metrics.appBytes))
                    legendRow(color: .orange, title: localizer.text(.memorySnapshotWiredMemory), value: memoryValueText(metrics.wiredBytes))
                    legendRow(color: .purple, title: localizer.text(.memorySnapshotCompressed), value: memoryValueText(metrics.compressedBytes))
                    legendRow(color: cachedMemoryColor, title: localizer.text(.memorySnapshotCachedFiles), value: memoryValueText(metrics.cachedBytes))
                    legendRow(color: .gray, title: localizer.text(.memorySnapshotFreeMemory), value: memoryValueText(metrics.freeBytes))
                }
            }
        }
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

    private func quickStatCard(title: String, value: String, accent: Color, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
            Capsule()
                .fill(tint.opacity(0.22))
                .frame(width: 26, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(innerCardBackground, in: RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: value)
    }

    private func usageSegment(color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .frame(width: max(width, 0))
    }

    private func legendRow(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(innerCardBackground, in: RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous))
    }

    private func errorState(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text(localizer.text(.memorySnapshotFailed))
                .font(.headline)

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
            return .yellow
        case .critical:
            return .red
        }
    }

    private func pressureAccentColor(for level: MemoryMetrics.PressureLevel) -> Color {
        switch level {
        case .normal:
            return Color(red: 0.22, green: 0.7, blue: 0.42)
        case .elevated:
            return .yellow
        case .critical:
            return .red
        }
    }

    private var cachedMemoryColor: Color {
        Color(red: 0.2, green: 0.58, blue: 0.82)
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

    private func pressureBadge(for level: MemoryMetrics.PressureLevel) -> some View {
        Label {
            Text(pressureDisplayName(level))
        } icon: {
            Image(systemName: pressureIconName(level))
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(pressureAccentColor(for: level).opacity(0.12), in: Capsule())
        .foregroundStyle(pressureAccentColor(for: level))
    }

    private func pressureIconName(_ level: MemoryMetrics.PressureLevel) -> String {
        switch level {
        case .normal:
            return "checkmark.circle.fill"
        case .elevated:
            return "exclamationmark.circle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }

    private func detailSection(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    metricRow(row.0, row.1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(innerCardBackground, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
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

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private func isPressureStable(for _: MemoryMetrics) -> Bool {
        guard viewModel.currentMetrics != nil, pressureChartPoints.count >= 4 else { return false }

        let recent = pressureChartPoints.suffix(6)
        guard let minValue = recent.map(\.score).min(),
              let maxValue = recent.map(\.score).max() else {
            return false
        }

        return (maxValue - minValue) < 0.035
    }

    private var stabilityBadge: some View {
        Label(localizer.text(.memorySnapshotPressureStable), systemImage: "waveform.path.ecg")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.055), in: Capsule())
    }

    private var pressureZoneLegend: some View {
        HStack(spacing: 12) {
            pressureZoneLegendItem(
                color: pressureAccentColor(for: .normal),
                title: localizer.text(.memorySnapshotPressureLegendNormal)
            )
            pressureZoneLegendItem(
                color: pressureAccentColor(for: .elevated),
                title: localizer.text(.memorySnapshotPressureLegendElevated)
            )
            pressureZoneLegendItem(
                color: pressureAccentColor(for: .critical),
                title: localizer.text(.memorySnapshotPressureLegendCritical)
            )
        }
        .font(.caption2)
    }

    private var pressureZoneScale: some View {
        HStack(spacing: 0) {
            pressureZoneScaleItem(
                title: localizer.text(.memorySnapshotPressureAxisLow),
                color: pressureAccentColor(for: .normal)
            )
            pressureZoneScaleItem(
                title: localizer.text(.memorySnapshotPressureAxisHigh),
                color: pressureAccentColor(for: .elevated)
            )
            pressureZoneScaleItem(
                title: localizer.text(.memorySnapshotPressureAxisCritical),
                color: pressureAccentColor(for: .critical)
            )
        }
        .padding(3)
        .background(Color.primary.opacity(0.03), in: Capsule())
    }

    private var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var innerCardBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    private func pressureChartDomain(for points: [PressureChartPoint]) -> ClosedRange<Date> {
        guard let first = points.first?.timestamp,
              let last = points.last?.timestamp else {
            let now = Date()
            return now.addingTimeInterval(-60)...now
        }

        if first == last {
            return first.addingTimeInterval(-30)...last.addingTimeInterval(30)
        }

        return first...last
    }

    private func chartTickDates(for points: [PressureChartPoint], domain: ClosedRange<Date>) -> [Date] {
        guard points.count >= 2 else { return [domain.lowerBound, domain.upperBound] }

        let preferredCount = min(max(points.count / 6, 3), 5)
        let total = domain.upperBound.timeIntervalSince(domain.lowerBound)
        guard total > 0 else { return [domain.lowerBound] }

        let step = total / Double(max(preferredCount - 1, 1))
        let dates = (0..<preferredCount).map { index in
            domain.lowerBound.addingTimeInterval(step * Double(index))
        }

        return deduplicatedAxisDates(dates)
    }

    private func deduplicatedAxisDates(_ dates: [Date]) -> [Date] {
        var seen = Set<String>()
        return dates.filter { date in
            let label = chartAxisLabel(for: date)
            if seen.contains(label) {
                return false
            }
            seen.insert(label)
            return true
        }
    }

    private func chartAxisLabel(for date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private func chartBackground(_ metrics: MemoryMetrics) -> some ShapeStyle {
        LinearGradient(
            colors: [
                pressureAccentColor(for: metrics.pressureLevel).opacity(0.035),
                Color.primary.opacity(0.016)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ChartContentBuilder
    private func pressureZoneMarks(domain: ClosedRange<Date>) -> some ChartContent {
        RectangleMark(
            xStart: .value("Start", domain.lowerBound),
            xEnd: .value("End", domain.upperBound),
            yStart: .value("Zone Start", 0),
            yEnd: .value("Zone End", pressureZoneLowerBound)
        )
        .foregroundStyle(pressureAccentColor(for: .normal).opacity(0.05))

        RectangleMark(
            xStart: .value("Start", domain.lowerBound),
            xEnd: .value("End", domain.upperBound),
            yStart: .value("Zone Start", pressureZoneLowerBound),
            yEnd: .value("Zone End", pressureZoneMiddleBound)
        )
        .foregroundStyle(pressureAccentColor(for: .elevated).opacity(0.045))

        RectangleMark(
            xStart: .value("Start", domain.lowerBound),
            xEnd: .value("End", domain.upperBound),
            yStart: .value("Zone Start", pressureZoneMiddleBound),
            yEnd: .value("Zone End", 1)
        )
        .foregroundStyle(pressureAccentColor(for: .critical).opacity(0.04))

        ForEach([pressureZoneLowerBound, pressureZoneMiddleBound], id: \.self) { threshold in
            RuleMark(y: .value("Threshold", threshold))
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                .foregroundStyle(Color.secondary.opacity(0.16))
        }
    }

    private func pressureZoneLegendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color.opacity(0.7))
                .frame(width: 10, height: 4)

            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    private func pressureZoneScaleItem(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(color.opacity(0.09), in: Capsule())
    }

    private var placeholderMetrics: MemoryMetrics {
        MemoryMetrics(
            timestamp: .now,
            totalBytes: 0,
            appBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0,
            cachedBytes: 0,
            freeBytes: 0,
            swapUsedBytes: 0,
            pageSizeBytes: 4096
        )
    }

    private var placeholderPressureChartPoints: [PressureChartPoint] {
        let now = Date()
        return stride(from: 4, through: 0, by: -1).map { step in
            PressureChartPoint(
                timestamp: now.addingTimeInterval(TimeInterval(-step * 15)),
                score: 0,
                isPlaceholder: true
            )
        }
    }

    private var headerUsageText: String {
        guard let metrics = viewModel.currentMetrics else {
            return "— / — \(localizer.text(.commonUsed))"
        }

        return "\(MemoryMetrics.format(bytes: metrics.usedBytes)) / \(MemoryMetrics.format(bytes: metrics.totalBytes)) \(localizer.text(.commonUsed))"
    }

    private var headerPressureText: String {
        guard let metrics = viewModel.currentMetrics else {
            return localizer.text(.memorySnapshotLoading)
        }

        return pressureDisplayName(metrics.pressureLevel)
    }

    private var headerStatusBadge: some View {
        Group {
            if viewModel.currentMetrics == nil {
                statusBadge(localizer.text(.memorySnapshotLoading))
            } else if viewModel.monitoringState == .paused {
                statusBadge(localizer.text(.commonPaused))
            } else {
                statusBadge(localizer.text(.commonLive))
            }
        }
    }

    private func statusBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.055), in: Capsule())
    }

    private func memoryValueText(_ bytes: Int64) -> String {
        guard viewModel.currentMetrics != nil else { return "—" }
        return MemoryMetrics.format(bytes: bytes)
    }

    private func breakdownSubtitle(_ metrics: MemoryMetrics) -> String {
        guard viewModel.currentMetrics != nil else {
            return localizer.text(.memorySnapshotLoading)
        }

        return localizer.format(.memorySnapshotUsageFootprint, MemoryMetrics.format(bytes: metrics.usedBytes))
    }
}

private struct PressureChartPoint: Identifiable, Equatable {
    let timestamp: Date
    let score: Double
    let isPlaceholder: Bool

    init(timestamp: Date, score: Double, isPlaceholder: Bool = false) {
        self.timestamp = timestamp
        self.score = score
        self.isPlaceholder = isPlaceholder
    }

    var id: Date { timestamp }

    var chartScore: Double {
        isPlaceholder ? 0.02 : score
    }

    var displayScore: Double {
        if isPlaceholder {
            return 0.02
        }

        if score <= 0.22 {
            return max(score, 0.12)
        }

        return score
    }

    var baselineScore: Double {
        if isPlaceholder {
            return 0
        }

        return min(displayScore, 0.04)
    }
}
