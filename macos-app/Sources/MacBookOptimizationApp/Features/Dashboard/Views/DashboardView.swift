import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: OptimizationDashboardViewModel
    @EnvironmentObject private var settings: AppSettingsStore

    private var localizer: AppLocalizer {
        AppLocalizer(language: settings.language)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationSplitView {
                sidebar
            } detail: {
                detailContent
            }
            .background(WindowCloseGuard(model: model, localizer: localizer))

            ToastCenterView(toasts: model.toasts) { toastID in
                model.dismissToast(id: toastID)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(
            isPresented: Binding(
                get: { model.pendingSystemActionReview != nil },
                set: { isPresented in
                    if !isPresented {
                        model.cancelSystemActionReview()
                    }
                }
            )
        ) {
            if let review = model.pendingSystemActionReview {
                SystemActionReviewSheet(review: review, localizer: localizer)
                    .environmentObject(model)
            }
        }
        .sheet(
            item: Binding(
                get: { model.presentedActionResult },
                set: { newValue in
                    if newValue == nil {
                        model.dismissPresentedActionResult()
                    }
                }
            )
        ) { presentedResult in
            ActionResultSheet(result: presentedResult, localizer: localizer)
                .environmentObject(model)
        }
        .confirmationDialog(
            localizer.text(.confirmRiskyTitle),
            isPresented: Binding(
                get: { model.pendingConfirmationAction != nil },
                set: { isPresented in
                    if !isPresented {
                        model.cancelPendingAction()
                    }
                }
            )
        ) {
            Button(localizer.text(.continueAction)) {
                model.confirmPendingAction()
            }
            Button(localizer.text(.cancel), role: .cancel) {
                model.cancelPendingAction()
            }
        } message: {
            if let action = model.pendingConfirmationAction {
                Text(confirmationMessage(for: action))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if settings.refreshInterval == .manual {
                    Button {
                        Task { await model.refreshStatuses() }
                    } label: {
                        Label(localizer.text(.manualRefresh), systemImage: "arrow.clockwise")
                    }
                }

                Button {
                    model.openSettings()
                } label: {
                    Label(localizer.text(.openSettings), systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $model.isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(settings)
                    .environmentObject(model)
            }
        }
    }

    private func confirmationMessage(for action: OptimizationAction) -> String {
        let base = "\(localizer.string(action.titleKey)). \(localizer.text(.confirmRiskyMessage))"
        guard action.kind.requiresAdministrator else { return base }
        return "\(base) \(localizer.format(.privilegedPromptMessage, localizer.string(action.titleKey)))"
    }

    private var sidebar: some View {
        List(selection: Binding(
            get: { model.selectedDestination },
            set: { if let value = $0 { model.showDestination(value) } }
        )) {
            Section(localizer.text(.summaryTitle)) {
                sidebarItem(localizer.text(.panelDashboard), systemImage: "macwindow", destination: .dashboard)
                sidebarItem(localizer.text(.panelAllStatuses), systemImage: "list.bullet.rectangle", destination: .statuses)
                sidebarItem(localizer.text(.activityTitle), systemImage: "bell.badge", destination: .activity)
                sidebarItem(localizer.text(.logsTitle), systemImage: "terminal", destination: .logs)
            }

            Section(localizer.text(.categories)) {
                ForEach(ActionCategory.allCases) { category in
                    sidebarItem(localizer.text(category.localizedKey), systemImage: category.symbolName, destination: .category(category))
                }
            }

            Section(localizer.text(.quickPanels)) {
                sidebarItem(localizer.text(.panelCPU), systemImage: "cpu", destination: .cpu)
                sidebarItem(localizer.text(.panelGPU), systemImage: "display.2", destination: .gpu)
                sidebarItem(localizer.text(.panelMemory), systemImage: "memorychip", destination: .memory)
                sidebarItem(localizer.text(.panelBattery), systemImage: "battery.75percent", destination: .battery)
                sidebarItem(localizer.text(.panelMDM), systemImage: "building.2.crop.circle", destination: .mdm)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .underPageBackgroundColor))
        .navigationTitle(localizer.text(.appTitle))
    }

    private func sidebarItem(_ title: String, systemImage: String, destination: SidebarDestination) -> some View {
        Label {
            Text(title)
                .font(.body.weight(model.selectedDestination == destination ? .semibold : .regular))
        } icon: {
            Image(systemName: systemImage)
                .symbolVariant(model.selectedDestination == destination ? .fill : .none)
                .foregroundStyle(model.selectedDestination == destination ? Color.accentColor : .secondary)
                .frame(width: 18)
        }
        .padding(.vertical, 4)
        .tag(destination)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch model.selectedDestination {
        case .dashboard:
            dashboardOverview
        case .statuses:
            StatusesPanelView(localizer: localizer, actions: model.actions)
                .environmentObject(model)
        case .activity:
            ActivityFeedView(
                localizer: localizer,
                filter: $model.activityFilter,
                items: model.filteredActivity,
                onDelete: { itemID in model.deleteActivity(id: itemID) },
                onClearAll: model.clearAllActivity
            )
        case .logs:
            LogsPanelView(
                localizer: localizer,
                output: model.logsTranscript,
                entries: model.debugLogEntries
            )
        case .category(let category):
            categoryDetail(category)
        case .cpu, .gpu, .memory, .battery, .mdm:
            quickPanelDetail
        }
    }

    private var dashboardOverview: some View {
        List {
            SystemInfoView(
                summary: model.machineSummary,
                memoryMetrics: model.memorySnapshotViewModel?.currentMetrics,
                localizer: localizer
            )

            Section(localizer.text(.actionsTitle)) {
                ForEach(model.actions.prefix(5)) { action in
                    ActionRowView(
                        action: action,
                        isRunning: model.isRunningActionID == action.id,
                        isAvailable: model.isActionAvailable(action),
                        availabilityMessage: model.unavailableMessage(for: action),
                        restoreMessage: model.restoreMessage(for: action),
                        localizer: localizer,
                        density: settings.rowDensity
                    ) {
                        Task { await model.run(actionID: action.id) }
                    } restoreAction: {
                        model.restore(actionID: action.id)
                    }
                }
            }
        }
        .listStyle(.inset)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func categoryDetail(_ category: ActionCategory) -> some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizer.text(category.localizedKey))
                            .font(.title3.weight(.semibold))

                        Text(localizer.text(.actionsTitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(localizer.text(.restoreCategoryButton)) {
                        model.restoreSelectedCategory()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 6)
            }

            Section {
                ForEach(model.visibleActions) { action in
                    ActionRowView(
                        action: action,
                        isRunning: model.isRunningActionID == action.id,
                        isAvailable: model.isActionAvailable(action),
                        availabilityMessage: model.unavailableMessage(for: action),
                        restoreMessage: model.restoreMessage(for: action),
                        localizer: localizer,
                        density: settings.rowDensity
                    ) {
                        Task { await model.run(actionID: action.id) }
                    } restoreAction: {
                        model.restore(actionID: action.id)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var quickPanelDetail: some View {
        switch model.selectedDestination {
        case .cpu:
            if let cpuVM = model.cpuSnapshotViewModel {
                CPUSnapshotView(viewModel: cpuVM)
                    .navigationTitle(localizer.text(.panelCPU))
            }
        case .gpu:
            if let gpuVM = model.gpuSnapshotViewModel {
                GPUSnapshotView(viewModel: gpuVM)
                    .navigationTitle(localizer.text(.panelGPU))
            }
        case .memory:
            if let memoryVM = model.memorySnapshotViewModel {
                MemorySnapshotView(viewModel: memoryVM)
                    .navigationTitle(localizer.text(.panelMemory))
            }
        case .battery:
            if let batteryVM = model.batterySnapshotViewModel {
                BatterySnapshotView(viewModel: batteryVM)
                    .navigationTitle(localizer.text(.panelBattery))
            }
        case .mdm:
            if let mdmVM = model.mdmSnapshotViewModel {
                MDMSnapshotView(viewModel: mdmVM)
                    .navigationTitle(localizer.text(.panelMDM))
            }
        default:
            Text(localizer.text(.noOutputYet))
                .foregroundStyle(.secondary)
        }
    }
}
