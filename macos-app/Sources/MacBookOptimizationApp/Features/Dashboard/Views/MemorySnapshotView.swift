import Charts
import SwiftUI

struct MemorySnapshotView: View {
    @ObservedObject var viewModel: MemorySnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel
    @State private var previousMetrics: MemoryMetrics?
    @State private var changedFields: Set<MemorySnapshotPresentation.ChangedField> = []

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

    private var headerPalette: MemorySnapshotPresentation.HeaderPalette {
        MemorySnapshotPresentation.headerPalette(for: displayMetrics)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headerSection

                if let error = viewModel.error {
                    errorState(error: error)
                } else {
                    adaptiveOverview(metrics: displayMetrics)
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
        .onChange(of: viewModel.currentMetrics) { metrics in
            guard let metrics else { return }

            let updatedFields = MemorySnapshotPresentation.changedFields(from: previousMetrics, to: metrics)
            previousMetrics = metrics

            withAnimation(.easeInOut(duration: 0.24)) {
                changedFields = updatedFields
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.45)) {
                    changedFields.subtract(updatedFields)
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(headerAccentColor.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: headerPalette.iconSymbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(headerAccentColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizer.text(.memorySnapshotTitle))
                            .font(.title2.weight(.semibold))

                        HStack(spacing: 8) {
                            Text(headerUsageText)
                                .modifier(ValuePulseModifier(isActive: changedFields.contains(.usage)))
                            Text("•")
                            Text(headerPressureText)
                                .foregroundStyle(viewModel.currentMetrics == nil ? .secondary : pressureColor(displayMetrics.pressureLevel))
                                .modifier(ValuePulseModifier(isActive: changedFields.contains(.pressure)))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func adaptiveOverview(metrics: MemoryMetrics) -> some View {
        VStack(spacing: 16) {
            pressureCard(metrics: metrics)
            detailsCard(metrics: metrics)
        }
    }

    private func pressureCard(metrics: MemoryMetrics) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(currentPressureAccent.opacity(0.16))
                                .frame(width: 38, height: 38)
                            Image(systemName: pressureIconName(metrics.pressureLevel))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(currentPressureAccent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizer.text(.memorySnapshotPressure))
                                .font(.headline)
                            Text(pressureHint(metrics))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
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
                        tint: .blue,
                        icon: "memorychip.fill",
                        highlight: changedFields.contains(.usage)
                    )
                    quickStatCard(
                        title: localizer.text(.memorySnapshotCachedFiles),
                        value: memoryValueText(metrics.cachedBytes),
                        accent: .primary,
                        tint: cachedMemoryColor,
                        icon: "externaldrive.fill",
                        highlight: changedFields.contains(.usage)
                    )
                    quickStatCard(
                        title: localizer.text(.memorySnapshotSwapUsed),
                        value: memoryValueText(metrics.swapUsedBytes),
                        accent: metrics.swapUsedBytes > 0 ? .primary : .secondary,
                        tint: metrics.swapUsedBytes > 0 ? pressureAccentColor(for: metrics.pressureLevel) : .secondary,
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        highlight: changedFields.contains(.swap)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailsCard(metrics: MemoryMetrics) -> some View {
        let breakdownItems = MemorySnapshotPresentation.usageBreakdownItems(for: metrics)
        let breakdownSpacing: CGFloat = 3

        return sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: localizer.text(.memorySnapshotUsageBreakdown),
                    subtitle: breakdownSubtitle(metrics)
                )

                metricSummaryRow(metrics: metrics)

                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        let segmentWidths = MemorySnapshotPresentation.usageBreakdownSegmentWidths(
                            values: breakdownItems.map(\.valueBytes),
                            totalWidth: geometry.size.width,
                            spacing: breakdownSpacing
                        )

                        HStack(spacing: breakdownSpacing) {
                            ForEach(Array(breakdownItems.enumerated()), id: \.offset) { index, item in
                                usageSegment(
                                    color: breakdownColor(for: item.titleKey),
                                    width: segmentWidths[index]
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                                .fill(Color.primary.opacity(0.025))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .frame(height: 18)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(breakdownItems.enumerated()), id: \.offset) { _, item in
                        breakdownLegendCard(item)
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

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body)

            Spacer(minLength: 12)

            Text(value)
                .font(.body.weight(.semibold))
        }
    }

    private func quickStatCard(title: String, value: String, accent: Color, tint: Color, icon: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .modifier(ValuePulseModifier(isActive: highlight))

            Capsule()
                .fill(tint.opacity(0.3))
                .frame(width: 30, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(innerCardBackground, in: RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                .stroke(highlight ? tint.opacity(0.2) : Color.primary.opacity(0.05), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: value)
    }

    private func usageSegment(color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color.opacity(0.88))
            .frame(width: max(width, 0))
    }

    private func metricSummaryRow(metrics: MemoryMetrics) -> some View {
        HStack(spacing: 12) {
            compactMetricPill(
                title: localizer.text(.memorySnapshotPhysicalMemory),
                value: memoryValueText(metrics.totalBytes),
                icon: "circle.grid.2x2.fill",
                tint: .blue
            )
            compactMetricPill(
                title: localizer.text(.memorySnapshotMemoryUsed),
                value: memoryValueText(metrics.usedBytes),
                icon: "memorychip.fill",
                tint: currentPressureAccent
            )
            compactMetricPill(
                title: localizer.text(.memorySnapshotSwapUsed),
                value: memoryValueText(metrics.swapUsedBytes),
                icon: "arrow.triangle.2.circlepath.circle.fill",
                tint: metrics.swapUsedBytes > 0 ? .orange : .secondary
            )
        }
    }

    private func compactMetricPill(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(innerCardBackground, in: RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    private func breakdownLegendCard(_ item: MemorySnapshotPresentation.UsageBreakdownItem) -> some View {
        let color = breakdownColor(for: item.titleKey)

        return HStack(spacing: 10) {
            Image(systemName: item.iconSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(localizer.text(item.titleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(memoryValueText(item.valueBytes))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(innerCardBackground, in: RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: miniCardCornerRadius, style: .continuous)
                .stroke(color.opacity(0.14), lineWidth: 1)
        )
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

    private func breakdownColor(for key: LocalizedKey) -> Color {
        switch key {
        case .memorySnapshotAppMemory:
            return .blue
        case .memorySnapshotWiredMemory:
            return .orange
        case .memorySnapshotCompressed:
            return .purple
        case .memorySnapshotCachedFiles:
            return cachedMemoryColor
        case .memorySnapshotFreeMemory:
            return .gray
        default:
            return .secondary
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
        .scaleEffect(changedFields.contains(.pressure) ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.35), value: changedFields.contains(.pressure))
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
            .overlay(cardBorder)
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

    private var headerAccentColor: Color {
        switch headerPalette.emphasis {
        case .normal:
            return Color(red: 0.17, green: 0.48, blue: 0.95)
        case .warning:
            return .orange
        case .critical:
            return .red
        }
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

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
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
                statusBadge(localizer.text(.memorySnapshotLoading), systemImage: "clock")
            } else if viewModel.monitoringState == .paused {
                statusBadge(localizer.text(.commonPaused), systemImage: "pause.fill")
            } else {
                statusBadge(localizer.text(.commonLive), systemImage: headerPalette.statusSymbol)
            }
        }
    }

    private func statusBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(viewModel.monitoringState == .paused ? .secondary : headerAccentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background((viewModel.monitoringState == .paused ? Color.primary.opacity(0.055) : headerAccentColor.opacity(0.12)), in: Capsule())
            .scaleEffect(changedFields.contains(.pressure) ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.35), value: changedFields.contains(.pressure))
    }

    private func memoryValueText(_ bytes: Int64) -> String {
        guard viewModel.currentMetrics != nil else { return "—" }
        return MemoryMetrics.format(bytes: bytes)
    }

    private func ratio(for bytes: Int64, totalBytes: Int64) -> CGFloat {
        guard totalBytes > 0 else { return 0 }
        return CGFloat(min(max(Double(bytes) / Double(totalBytes), 0), 1))
    }

    private func breakdownSubtitle(_ metrics: MemoryMetrics) -> String {
        guard viewModel.currentMetrics != nil else {
            return localizer.text(.memorySnapshotLoading)
        }

        return localizer.format(.memorySnapshotUsageFootprint, MemoryMetrics.format(bytes: metrics.usedBytes))
    }
}

private struct ValuePulseModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.03 : 1.0)
            .opacity(isActive ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.35), value: isActive)
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
