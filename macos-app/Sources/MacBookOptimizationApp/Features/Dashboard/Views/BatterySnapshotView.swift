import Charts
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

    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                if let metrics = viewModel.currentMetrics {
                    adaptiveOverview(metrics: metrics)
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
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizer.text(.batterySnapshotTitle))
                    .font(.title2)
                    .fontWeight(.semibold)

                if let metrics = viewModel.currentMetrics {
                    Text("\(metrics.level)% • \(chargingStateText(metrics.chargingState))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $viewModel.refreshInterval) {
                    ForEach(BatterySnapshotViewModel.RefreshInterval.allCases) { interval in
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
    private func adaptiveOverview(metrics: BatteryMetrics) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                statusCard(metrics: metrics)
                healthCard(metrics: metrics)
                chargerCard(metrics: metrics)
                batteryDetailsCard(metrics: metrics)
            }

            VStack(spacing: 16) {
                statusCard(metrics: metrics)
                healthCard(metrics: metrics)
                chargerCard(metrics: metrics)
                batteryDetailsCard(metrics: metrics)
            }
        }
    }

    private func statusCard(metrics: BatteryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.text(.batterySnapshotLevel))
                .font(.headline)

            batteryLevelGauge(metrics: metrics)

            VStack(spacing: 10) {
                statusRow(
                    icon: powerSourceIcon(metrics.powerSource),
                    title: localizer.text(.batterySnapshotPowerSource),
                    value: powerSourceText(metrics.powerSource)
                )
                statusRow(
                    icon: chargingStateIcon(metrics.chargingState),
                    title: localizer.text(.batterySnapshotChargingState),
                    value: chargingStateText(metrics.chargingState)
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func healthCard(metrics: BatteryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localizer.text(.batterySnapshotHealth))
                    .font(.headline)

                Spacer()

                Text(conditionText(metrics.condition))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(conditionColor(metrics.condition).opacity(0.12), in: Capsule())
                    .foregroundStyle(conditionColor(metrics.condition))
            }

            VStack(spacing: 10) {
                healthRow(
                    title: localizer.text(.batterySnapshotCycleCount),
                    value: "\(metrics.cycleCount)"
                )
            }

            if let health = metrics.healthPercentage {
                healthCapacitySection(metrics: metrics, health: health)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chargerCard(metrics: BatteryMetrics) -> some View {
        let content = BatterySnapshotChargerInfoContent(
            metrics: metrics,
            unavailableText: localizer.text(.unavailable)
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text(localizer.text(.batterySnapshotChargerInfo))
                .font(.headline)
            
            VStack(spacing: 10) {
                detailRow(
                    icon: "bolt.fill",
                    title: localizer.text(.batterySnapshotChargerWattage),
                    value: content.wattageText
                )

                detailRow(
                    icon: "powerplug.fill",
                    title: localizer.text(.batterySnapshotAdapterName),
                    value: content.adapterNameText
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func healthCapacitySection(metrics: BatteryMetrics, health: Double) -> some View {
        VStack(spacing: 16) {
            capacityProgressCard(
                title: "Sức khỏe pin",
                value: capacityHealthDescription(metrics: metrics, health: health),
                progress: health / 100.0,
                progressLabel: String(format: "%.1f%%", health),
                tint: healthColor(health)
            )
        }
    }

    private func capacityProgressCard(
        title: String,
        value: String,
        progress: Double,
        progressLabel: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.body)

                Spacer(minLength: 12)

                Text(value)
                    .font(.body.weight(.semibold))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.gray.opacity(0.14))

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint)
                        .frame(width: geometry.size.width * CGFloat(max(0, min(progress, 1))))

                    Text(progressLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 30)
        }
        .padding(.vertical, 4)
    }

    private func batteryDetailsCard(metrics: BatteryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.text(.batterySnapshotBatteryDetails))
                .font(.headline)
            
            VStack(spacing: 10) {
                temperatureRow(temperature: metrics.temperature)
                manufactureDateRow(date: metrics.manufactureDate)
                serialNumberRow(serialNumber: metrics.serialNumber)
                lowPowerModeRow(isEnabled: metrics.isLowPowerModeEnabled)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func temperatureRow(temperature: Double?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "thermometer")
                .font(.body)
                .foregroundStyle(temperature != nil ? temperatureColor(temperature!) : .secondary)
                .frame(width: 20)
            
            Text(localizer.text(.batterySnapshotTemperature))
                .font(.subheadline)
            
            Spacer()
            
            if let temp = temperature {
                Text(String(format: "%.1f°C", temp))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(temperatureColor(temp))
            } else {
                Text(localizer.text(.unavailable))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func manufactureDateRow(date: Date?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(localizer.text(.batterySnapshotManufactureDate))
                .font(.subheadline)
            
            Spacer()
            
            if let manufactureDate = date {
                Text(formatDate(manufactureDate))
                    .font(.subheadline.weight(.semibold))
            } else {
                Text(localizer.text(.unavailable))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func serialNumberRow(serialNumber: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "number")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(localizer.text(.batterySnapshotSerialNumber))
                .font(.subheadline)
            
            Spacer()
            
            if let serial = serialNumber {
                Text(serial)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
            } else {
                Text(localizer.text(.unavailable))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func lowPowerModeRow(isEnabled: Bool?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.body)
                .foregroundStyle(lowPowerModeColor(isEnabled))
                .frame(width: 20)
            
            Text(localizer.text(.batterySnapshotLowPowerMode))
                .font(.subheadline)
            
            Spacer()
            
            Text(lowPowerModeText(isEnabled))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(lowPowerModeColor(isEnabled))
        }
    }

    private func batteryLevelGauge(metrics: BatteryMetrics) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.12))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                batteryLevelColor(metrics.level).opacity(0.35),
                                batteryLevelColor(metrics.level).opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(metrics.level) / 100.0)

                HStack {
                    Image(systemName: batteryIcon(level: metrics.level, isCharging: metrics.isCharging))
                        .foregroundStyle(batteryLevelColor(metrics.level))
                        .font(.title2)

                    Text("\(metrics.level)%")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 60)
    }

    private func healthIndicator(percentage: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.12))

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(healthColor(percentage))
                    .frame(width: geometry.size.width * CGFloat(percentage) / 100.0)

                HStack(spacing: 6) {
                    Circle()
                        .fill(healthColor(percentage))
                        .frame(width: 8, height: 8)
                    Text(String(format: "%.1f%% \(localizer.text(.batterySnapshotHealthStatus))", percentage))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(height: 28)
    }

    private func statusRow(icon: String, title: String, value: String) -> some View {
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
        }
    }

    private func healthRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body)

            Spacer(minLength: 12)

            Text(value)
                .font(.body.weight(.semibold))
        }
    }

    private func capacityRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body)

            Spacer(minLength: 12)

            Text(value)
                .font(.body.weight(.semibold))
        }
    }

    private func capacityHealthDescription(metrics: BatteryMetrics, health: Double) -> String {
        guard let full = metrics.fullChargeCapacity,
              let design = metrics.designCapacity else {
            return String(format: "%.1f%%", health)
        }

        return "\(full) mAh / \(design) mAh"
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
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
