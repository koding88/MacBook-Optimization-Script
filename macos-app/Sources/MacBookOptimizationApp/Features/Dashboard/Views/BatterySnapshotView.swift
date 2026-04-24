import SwiftUI

struct BatterySnapshotChargerInfoContent {
    let wattageText: String
    let adapterNameText: String

    init(metrics: BatteryMetrics, unavailableText: String) {
        if let wattage = metrics.chargerWattage {
            self.wattageText = "\(wattage)W"
        } else {
            self.wattageText = unavailableText
        }

        self.adapterNameText = metrics.chargerAdapterName ?? unavailableText
    }
}

struct BatterySnapshotView: View {
    @ObservedObject var viewModel: BatterySnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel
    @State private var previousMetrics: BatteryMetrics?
    @State private var changedFields: Set<BatterySnapshotPresentation.ChangedField> = []

    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerSection

                if let metrics = viewModel.currentMetrics {
                    metricsStack(metrics: metrics)
                } else if let error = viewModel.error {
                    errorState(error: error)
                } else if viewModel.isMonitoring {
                    ProgressView(localizer.text(.batterySnapshotCollecting))
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .onAppear {
            if viewModel.monitoringState == .notStarted {
                if viewModel.refreshInterval != .manual {
                    viewModel.startMonitoring()
                } else {
                    viewModel.manualRefresh()
                }
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
            let updatedFields = BatterySnapshotPresentation.changedFields(from: previousMetrics, to: metrics)
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(localizer.text(.batterySnapshotTitle))
                    .font(.title2)
                .fontWeight(.semibold)

                if let metrics = viewModel.currentMetrics {
                    Text("\(metrics.level)% • \(chargingStateText(metrics.chargingState))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isMonitoring ? Color.green.opacity(0.85) : Color.secondary.opacity(0.6))
                        .frame(width: 6, height: 6)

                    Text(
                        BatterySnapshotPresentation.lastUpdatedText(
                            updatedAt: viewModel.currentMetrics?.timestamp,
                            localizer: localizer
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if viewModel.refreshInterval == .manual {
                    Button(action: { viewModel.manualRefresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Text("\(localizer.text(.batterySnapshotAutoRefresh)):")
                    .font(.callout)
                    .foregroundColor(.secondary)

                Picker(
                    "",
                    selection: Binding(
                        get: { viewModel.refreshInterval },
                        set: { viewModel.updateRefreshInterval($0) }
                    )
                ) {
                    ForEach(BatterySnapshotViewModel.RefreshInterval.allCases) { interval in
                        Text(localizer.text(interval.localizationKey)).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func metricsStack(metrics: BatteryMetrics) -> some View {
        VStack(spacing: 10) {
            statusCard(metrics: metrics)
            healthCard(metrics: metrics)
            chargerCard(metrics: metrics)
            batteryDetailsCard(metrics: metrics)
        }
    }

    private func statusCard(metrics: BatteryMetrics) -> some View {
        snapshotCard {
            cardTitle(localizer.text(.batterySnapshotLevel))

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: batteryIcon(level: metrics.level, isCharging: metrics.isCharging))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(batteryLevelColor(metrics.level).opacity(0.9))

                Text("\(metrics.level)%")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.primary)
                    .modifier(ValuePulseModifier(isActive: changedFields.contains(.level)))

                Divider()
                    .frame(height: 16)

                Text(chargingStateText(metrics.chargingState))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(chargingStateColor(metrics.chargingState))
                    .modifier(ValuePulseModifier(isActive: changedFields.contains(.chargingState)))

                Spacer(minLength: 0)

                Text(powerSourceText(metrics.powerSource))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .modifier(ValuePulseModifier(isActive: changedFields.contains(.powerSource)))
            }

            insightText(
                BatterySnapshotPresentation.levelInsight(metrics: metrics, localizer: localizer)
            )

            batteryLevelGauge(metrics: metrics)

            HStack(spacing: 14) {
                compactMetric(
                    icon: powerSourceIcon(metrics.powerSource),
                    title: localizer.text(.batterySnapshotPowerSource),
                    value: powerSourceText(metrics.powerSource),
                    valueColor: .primary,
                    iconColor: powerSourceColor(metrics.powerSource)
                )

                Divider()
                    .frame(height: 18)

                compactMetric(
                    icon: chargingStateIcon(metrics.chargingState),
                    title: localizer.text(.batterySnapshotChargingState),
                    value: chargingStateText(metrics.chargingState),
                    valueColor: .primary,
                    iconColor: chargingStateColor(metrics.chargingState)
                )

                Spacer(minLength: 0)
            }
        }
        .help(BatterySnapshotPresentation.levelInsight(metrics: metrics, localizer: localizer))
        .batteryCardPresentation(
            highlight: changedFields.contains(.level) || changedFields.contains(.powerSource) || changedFields.contains(.chargingState)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func healthCard(metrics: BatteryMetrics) -> some View {
        snapshotCard {
            HStack(alignment: .top, spacing: 12) {
                cardTitle(localizer.text(.batterySnapshotHealth))

                Spacer()

                statusCapsule(
                    text: conditionText(metrics.condition),
                    color: conditionColor(metrics.condition)
                )
            }

            insightText(
                BatterySnapshotPresentation.healthInsight(metrics: metrics, localizer: localizer)
            )

            if let health = metrics.healthPercentage {
                healthCapacitySection(metrics: metrics, health: health)
            }

            compactMetric(
                icon: "repeat",
                title: localizer.text(.batterySnapshotCycleCount),
                value: "\(metrics.cycleCount)",
                valueColor: .primary,
                iconColor: conditionColor(metrics.condition)
            )
        }
        .help(localizer.text(.batterySnapshotHelpBatteryHealth))
        .batteryCardPresentation(
            highlight: changedFields.contains(.health)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chargerCard(metrics: BatteryMetrics) -> some View {
        let content = BatterySnapshotChargerInfoContent(
            metrics: metrics,
            unavailableText: localizer.text(.unavailable)
        )

        return snapshotCard {
            cardTitle(localizer.text(.batterySnapshotChargerInfo))

            insightText(
                BatterySnapshotPresentation.chargerInsight(metrics: metrics, localizer: localizer)
            )

            HStack(alignment: .top, spacing: 18) {
                compactMetric(
                    icon: "bolt.fill",
                    title: localizer.text(.batterySnapshotChargerWattage),
                    value: content.wattageText,
                    valueColor: .primary,
                    iconColor: .orange
                )

                Divider()
                    .frame(height: 18)

                compactMetric(
                    icon: "powerplug.fill",
                    title: localizer.text(.batterySnapshotAdapterName),
                    value: content.adapterNameText,
                    valueColor: .primary,
                    iconColor: .blue
                )

                Spacer(minLength: 0)
            }
        }
        .help(localizer.text(.batterySnapshotHelpCharger))
        .batteryCardPresentation(
            highlight: changedFields.contains(.charger)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func healthCapacitySection(metrics: BatteryMetrics, health: Double) -> some View {
        capacityProgressCard(
            title: localizer.text(.batterySnapshotCapacityDetails),
            value: capacityHealthDescription(metrics: metrics, health: health),
            progress: health / 100.0,
            progressLabel: String(format: "%.1f%%", health),
            tint: healthColor(health)
        )
    }

    private func capacityProgressCard(
        title: String,
        value: String,
        progress: Double,
        progressLabel: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Text(progressLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(tint.opacity(0.85))
                    .modifier(ValuePulseModifier(isActive: changedFields.contains(.health)))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.06))

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(tint.opacity(0.26))
                        .frame(width: geometry.size.width * CGFloat(max(0, min(progress, 1))))
                }
            }
            .frame(height: 7)
            .animation(.easeInOut(duration: 0.45), value: progress)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func batteryDetailsCard(metrics: BatteryMetrics) -> some View {
        snapshotCard {
            cardTitle(localizer.text(.batterySnapshotBatteryDetails))

            insightText(
                BatterySnapshotPresentation.detailInsight(metrics: metrics, localizer: localizer)
            )

            VStack(alignment: .leading, spacing: 8) {
                temperatureHighlightRow(temperature: metrics.temperature)

                detailRow(
                    icon: "leaf.fill",
                    title: localizer.text(.batterySnapshotLowPowerMode),
                    value: lowPowerModeText(metrics.isLowPowerModeEnabled),
                    valueColor: lowPowerModeColor(metrics.isLowPowerModeEnabled),
                    labelColor: .secondary,
                    iconColor: lowPowerModeColor(metrics.isLowPowerModeEnabled)
                )
                metadataRow(
                    icon: "calendar",
                    title: localizer.text(.batterySnapshotManufactureDate),
                    value: manufactureDateValue(metrics.manufactureDate)
                )
                metadataRow(
                    icon: "number",
                    title: localizer.text(.batterySnapshotSerialNumber),
                    value: serialNumberValue(metrics.serialNumber),
                    monospacedValue: metrics.serialNumber != nil
                )
            }
        }
        .help(localizer.text(.batterySnapshotHelpTemperature))
        .batteryCardPresentation(
            highlight: changedFields.contains(.temperature) || changedFields.contains(.lowPowerMode)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func temperatureHighlightRow(temperature: Double?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "thermometer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(temperature.map(temperatureColor) ?? .secondary)
                .frame(width: 20)

            Text(localizer.text(.batterySnapshotTemperature))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if let temp = temperature {
                Text(String(format: "%.1f°C", temp))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(temperatureColor(temp))
                    .modifier(ValuePulseModifier(isActive: changedFields.contains(.temperature)))
            } else {
                Text(localizer.text(.unavailable))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }

    private func batteryLevelGauge(metrics: BatteryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))

                    Capsule(style: .continuous)
                        .fill(batteryLevelColor(metrics.level).opacity(0.3))
                        .frame(width: geometry.size.width * CGFloat(metrics.level) / 100.0)
                }
            }
            .frame(height: 10)
            .animation(.easeInOut(duration: 0.45), value: metrics.level)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func capacityHealthDescription(metrics: BatteryMetrics, health: Double) -> String {
        guard let full = metrics.fullChargeCapacity,
              let design = metrics.designCapacity else {
            return String(format: "%.1f%%", health)
        }

        return "\(full) mAh / \(design) mAh"
    }

    private func detailRow(
        icon: String? = nil,
        title: String,
        value: String,
        valueColor: Color = .primary,
        labelColor: Color = .secondary,
        iconColor: Color? = nil
    ) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor ?? labelColor)
                    .frame(width: 20)
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(labelColor)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }

    private func metadataRow(
        icon: String,
        title: String,
        value: String,
        monospacedValue: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.8))
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Group {
                if monospacedValue {
                    Text(value)
                        .font(.system(.footnote, design: .monospaced).weight(.medium))
                } else {
                    Text(value)
                        .font(.subheadline.weight(.medium))
                }
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
        }
    }

    private func compactMetric(
        icon: String,
        title: String,
        value: String,
        valueColor: Color = .primary,
        iconColor: Color = .secondary
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func snapshotCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statusCapsule(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1), in: Capsule())
            .foregroundStyle(color.opacity(0.9))
    }

    private func insightText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func manufactureDateValue(_ date: Date?) -> String {
        guard let date else { return localizer.text(.unavailable) }
        return formatDate(date)
    }

    private func serialNumberValue(_ serialNumber: String?) -> String {
        guard let serialNumber else { return localizer.text(.unavailable) }
        return serialNumber
    }

    private func errorState(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text(localizer.text(.batterySnapshotFailed))
                .font(.headline)

            Text(error)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "battery.100")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(localizer.text(.batterySnapshotNotStarted))
                .font(.headline)

            Text(localizer.text(.batterySnapshotClickToStart))
                .foregroundStyle(.secondary)

            Button(localizer.text(.batterySnapshotStartMonitoring)) {
                viewModel.startMonitoring()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func powerSourceIcon(_ source: BatteryMetrics.PowerSource) -> String {
        switch source {
        case .ac: return "bolt.fill"
        case .battery: return "battery.100"
        case .unknown: return "questionmark.circle"
        }
    }

    private func powerSourceText(_ source: BatteryMetrics.PowerSource) -> String {
        switch source {
        case .ac: return localizer.text(.batteryPowerSourceAC)
        case .battery: return localizer.text(.batteryPowerSourceBattery)
        case .unknown: return localizer.text(.unavailable)
        }
    }

    private func chargingStateIcon(_ state: BatteryMetrics.ChargingState) -> String {
        switch state {
        case .charging: return "bolt.fill"
        case .discharging: return "arrow.down.circle"
        case .charged: return "checkmark.circle.fill"
        case .acAttached: return "bolt.slash"
        case .unknown: return "questionmark.circle"
        }
    }

    private func chargingStateText(_ state: BatteryMetrics.ChargingState) -> String {
        switch state {
        case .charging: return localizer.text(.batteryStateCharging)
        case .discharging: return localizer.text(.batteryStateDischarging)
        case .charged: return localizer.text(.batteryStateCharged)
        case .acAttached: return localizer.text(.batteryStateACAttached)
        case .unknown: return localizer.text(.unavailable)
        }
    }

    private func conditionText(_ condition: BatteryMetrics.BatteryCondition) -> String {
        switch condition {
        case .normal: return localizer.text(.batteryConditionNormal)
        case .replaceSoon: return localizer.text(.batteryConditionReplaceSoon)
        case .replaceNow: return localizer.text(.batteryConditionReplaceNow)
        case .serviceBattery: return localizer.text(.batteryConditionServiceBattery)
        case .unknown: return localizer.text(.unavailable)
        }
    }

    private func conditionColor(_ condition: BatteryMetrics.BatteryCondition) -> Color {
        switch condition {
        case .normal: return .green
        case .replaceSoon: return .orange
        case .replaceNow, .serviceBattery: return .red
        case .unknown: return .gray
        }
    }

    private func batteryIcon(level: Int, isCharging: Bool) -> String {
        if isCharging {
            return "bolt.fill"
        }

        if level >= 75 {
            return "battery.100"
        } else if level >= 50 {
            return "battery.75"
        } else if level >= 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }

    private func batteryLevelColor(_ level: Int) -> Color {
        if level >= 50 {
            return .green
        } else if level >= 20 {
            return .orange
        } else {
            return .red
        }
    }

    private func healthColor(_ percentage: Double) -> Color {
        if percentage >= 80 {
            return .green
        } else if percentage >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    private func powerSourceColor(_ source: BatteryMetrics.PowerSource) -> Color {
        switch source {
        case .ac:
            return .blue
        case .battery:
            return .green
        case .unknown:
            return .secondary
        }
    }

    private func chargingStateColor(_ state: BatteryMetrics.ChargingState) -> Color {
        switch state {
        case .charging, .charged:
            return .green
        case .discharging:
            return .orange
        case .acAttached:
            return .blue
        case .unknown:
            return .secondary
        }
    }
    
    private func temperatureColor(_ temp: Double) -> Color {
        if temp < 30 {
            return .green
        } else if temp <= 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func lowPowerModeColor(_ isEnabled: Bool?) -> Color {
        guard let enabled = isEnabled else { return .gray }
        return enabled ? .green : .gray
    }
    
    private func lowPowerModeText(_ isEnabled: Bool?) -> String {
        guard let enabled = isEnabled else {
            return localizer.text(.unavailable)
        }
        return enabled ? localizer.text(.batterySnapshotLowPowerModeEnabled) : localizer.text(.batterySnapshotLowPowerModeDisabled)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct ValuePulseModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.03 : 1.0)
            .opacity(isActive ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.35), value: isActive)
    }
}

private struct BatteryCardPresentationModifier: ViewModifier {
    let highlight: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(highlight ? Color.accentColor.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.3), value: highlight)
    }
}

private extension View {
    func batteryCardPresentation(highlight: Bool) -> some View {
        modifier(BatteryCardPresentationModifier(highlight: highlight))
    }
}

private extension BatterySnapshotView {
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    }
}
