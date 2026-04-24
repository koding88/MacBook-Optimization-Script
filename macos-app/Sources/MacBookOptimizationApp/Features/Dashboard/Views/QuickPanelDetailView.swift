import SwiftUI

struct QuickPanelDetailView: View {
    @EnvironmentObject private var model: OptimizationDashboardViewModel

    let action: OptimizationAction
    let localizer: AppLocalizer

    private var panelState: QuickPanelState? {
        model.quickPanelState(for: action.id)
    }

    private var latestLogEntry: DebugLogEntry? {
        model.latestLogEntry(for: action.id)
    }

    private var terminalOutput: String {
        latestLogEntry?.transcript ?? panelState?.details ?? ""
    }

    private var viewIdentity: String {
        [
            action.id,
            panelState?.summary?.primaryValue ?? "no-summary",
            latestLogEntry?.id.uuidString ?? "no-log"
        ].joined(separator: "|")
    }

    var body: some View {
        Group {
            if action.id == "system_check_cpu", let cpuVM = model.cpuSnapshotViewModel {
                CPUSnapshotView(viewModel: cpuVM)
                    .navigationTitle(localizer.string(action.titleKey))
            } else if action.id == "system_check_gpu", let gpuVM = model.gpuSnapshotViewModel {
                GPUSnapshotView(viewModel: gpuVM)
                    .navigationTitle(localizer.string(action.titleKey))
            } else if action.id == "system_check_memory", let memoryVM = model.memorySnapshotViewModel {
                MemorySnapshotView(viewModel: memoryVM)
                    .navigationTitle(localizer.string(action.titleKey))
            } else if action.id == "system_check_battery", let batteryVM = model.batterySnapshotViewModel {
                BatterySnapshotView(viewModel: batteryVM)
                    .navigationTitle(localizer.string(action.titleKey))
            } else if action.id == "mdm_status", let mdmVM = model.mdmSnapshotViewModel {
                MDMSnapshotView(viewModel: mdmVM)
                    .navigationTitle(localizer.string(action.titleKey))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(localizer.string(action.titleKey))
                                    .font(.title2.weight(.semibold))

                                Text(localizer.string(action.descriptionKey))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(localizer.text(.run)) {
                                Task { await model.run(actionID: action.id) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isRunningActionID == action.id)
                        }

                        if let summary = panelState?.summary {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(summary.primaryValue)
                                    .font(.title3.weight(.semibold))

                                ForEach(Array(summary.secondaryValues.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(localizer.text(item.labelKey))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)

                                        Spacer(minLength: 8)

                                        Text(item.value)
                                            .font(.subheadline.weight(.medium))
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        TerminalSurfaceView(
                            title: localizer.string(action.titleKey),
                            output: terminalOutput,
                            emptyMessage: localizer.text(.noOutputYet),
                            animateKey: latestLogEntry?.id.uuidString ?? action.id,
                            minHeight: 260,
                            maxHeight: nil
                        )
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .id(viewIdentity)
                .navigationTitle(localizer.string(action.titleKey))
            }
        }
    }
}
