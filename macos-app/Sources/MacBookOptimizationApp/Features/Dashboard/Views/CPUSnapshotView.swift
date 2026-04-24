import SwiftUI
import Charts

struct CPUSnapshotView: View {
    @ObservedObject var viewModel: CPUSnapshotViewModel
    @EnvironmentObject private var dashboardModel: OptimizationDashboardViewModel
    
    private var localizer: AppLocalizer {
        AppLocalizer(language: dashboardModel.settings.language)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                
                if viewModel.currentMetrics != nil {
                    cpuUsageChart
                    
                    HStack(spacing: 16) {
                        clusterActivitySection
                        coreFrequencyHeatmap
                    }
                    
                    coreResidencyBars
                    
                    HStack(spacing: 16) {
                        frequencyDistributionChart
                        powerConsumptionGauges
                    }
                } else if viewModel.isMonitoring {
                    ProgressView(localizer.text(.cpuSnapshotCollecting))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .onAppear {
            // Only start if not already started
            // If paused, resume without requiring password
            if viewModel.monitoringState == .notStarted {
                viewModel.startMonitoring()
            } else if viewModel.monitoringState == .paused {
                viewModel.resumeMonitoring()
            }
        }
        .onDisappear {
            // Pause instead of stop to keep powermetrics running
            // This avoids requiring password when user returns
            if viewModel.monitoringState == .running {
                viewModel.pauseMonitoring()
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizer.text(.cpuSnapshotTitle))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let metrics = viewModel.currentMetrics {
                    HStack(spacing: 8) {
                        Text(metrics.cpuName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(metrics.totalCores) \(localizer.text(.cpuSnapshotCores))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(localizer.text(.cpuSnapshotThermal)): \(metrics.thermalPressure.displayName)")
                            .font(.subheadline)
                            .foregroundColor(thermalColor(metrics.thermalPressure))
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("\(localizer.text(.cpuSnapshotAutoRefresh)):")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $viewModel.refreshInterval) {
                    ForEach(CPUSnapshotViewModel.RefreshInterval.allCases) { interval in
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
    
    private var cpuUsageChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.text(.cpuSnapshotOverallUsage))
                .font(.headline)
            
            if viewModel.metricsHistory.count >= 2 {
                Chart {
                    ForEach(Array(viewModel.cpuUsageChartData.enumerated()), id: \.offset) { _, data in
                        LineMark(
                            x: .value("Time", data.0),
                            y: .value("Usage", data.1)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        
                        AreaMark(
                            x: .value("Time", data.0),
                            y: .value("Usage", data.1)
                        )
                        .foregroundStyle(Color.blue.opacity(0.1).gradient)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue))%")
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .frame(height: 150)
            } else {
                Text(localizer.text(.cpuSnapshotCollectingData))
                    .foregroundColor(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var clusterActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.text(.cpuSnapshotClusterActivity))
                .font(.headline)
            
            if let metrics = viewModel.currentMetrics {
                ForEach(metrics.clusters) { cluster in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cluster.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(cluster.activeResidency))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                
                                Rectangle()
                                    .fill(clusterColor(cluster.name))
                                    .frame(width: geometry.size.width * (cluster.activeResidency / 100))
                            }
                        }
                        .frame(height: 8)
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
    
    private var coreFrequencyHeatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.text(.cpuSnapshotPerCoreFrequency))
                .font(.headline)
            
            if let metrics = viewModel.currentMetrics {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
                
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(metrics.cores) { core in
                        VStack(spacing: 2) {
                            Text("\(core.id)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("\(core.frequency)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(frequencyColor(core.frequency, max: 3500))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
    
    private var coreResidencyBars: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.text(.cpuSnapshotCoreResidency))
                .font(.headline)
            
            if let metrics = viewModel.currentMetrics {
                ForEach(metrics.clusters) { cluster in
                    HStack(spacing: 8) {
                        Text(cluster.name)
                            .font(.subheadline)
                            .frame(width: 100, alignment: .leading)
                        
                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * (cluster.activeResidency / 100))
                                
                                Rectangle()
                                    .fill(Color.yellow)
                                    .frame(width: geometry.size.width * (cluster.idleResidency / 100))
                                
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: geometry.size.width * (cluster.downResidency / 100))
                            }
                        }
                        .frame(height: 24)
                        .cornerRadius(4)
                        
                        Text("\(Int(cluster.activeResidency))% / \(Int(cluster.idleResidency))% / \(Int(cluster.downResidency))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var frequencyDistributionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.text(.cpuSnapshotFrequencyDistribution))
                .font(.headline)
            
            // Show the first cluster that has frequency distribution data
            if let metrics = viewModel.currentMetrics,
               let cluster = metrics.clusters.first(where: { !$0.frequencyDistribution.isEmpty }) {
                if cluster.frequencyDistribution.isEmpty {
                    Text("No frequency data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                } else {
                    Chart {
                        ForEach(cluster.frequencyDistribution, id: \.frequency) { bucket in
                            BarMark(
                                x: .value("Frequency", bucket.frequency),
                                y: .value("Percentage", bucket.percentage)
                            )
                            .foregroundStyle(Color.purple.gradient)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let frequency = value.as(Int.self) {
                                    Text("\(frequency)")
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let intValue = value.as(Double.self) {
                                    Text("\(Int(intValue))%")
                                }
                            }
                        }
                    }
                    .frame(height: 150)
                }
            } else {
                Text("No frequency distribution data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 150)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
    
    private var powerConsumptionGauges: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.text(.cpuSnapshotPowerConsumption))
                .font(.headline)
            
            if let metrics = viewModel.currentMetrics {
                VStack(spacing: 12) {
                    powerGauge(label: "CPU", value: metrics.power.cpu, max: 2000, color: .blue)
                    powerGauge(label: "GPU", value: metrics.power.gpu, max: 2000, color: .green)
                    powerGauge(label: "Total", value: metrics.power.combined, max: 4000, color: .orange)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
    
    private func powerGauge(label: String, value: Int, max: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .frame(width: 50, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * (Double(value) / Double(max)))
                }
            }
            .frame(height: 20)
            .cornerRadius(10)
            
            Text("\(value) mW")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(localizer.text(.cpuSnapshotNotStarted))
                .font(.headline)
            
            Text(localizer.text(.cpuSnapshotClickToStart))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(localizer.text(.cpuSnapshotStartMonitoring)) {
                viewModel.startMonitoring()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // Helper functions
    private func thermalColor(_ pressure: CPUMetrics.ThermalPressure) -> Color {
        switch pressure {
        case .nominal: return .green
        case .moderate: return .yellow
        case .heavy, .trapping: return .orange
        case .sleeping: return .gray
        }
    }
    
    private func clusterColor(_ name: String) -> Color {
        if name.contains("E-") { return .blue }
        if name.contains("P0-") { return .green }
        if name.contains("P1-") { return .purple }
        return .gray
    }
    
    private func frequencyColor(_ frequency: Int, max: Int) -> Color {
        let ratio = Double(frequency) / Double(max)
        if ratio < 0.3 { return Color.blue.opacity(0.3) }
        if ratio < 0.6 { return Color.green.opacity(0.5) }
        if ratio < 0.8 { return Color.yellow.opacity(0.7) }
        return Color.red.opacity(0.8)
    }
}
