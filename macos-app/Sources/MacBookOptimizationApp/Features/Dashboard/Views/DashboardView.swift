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

            ToastCenterView(toasts: model.toasts) { toastID in
                model.dismissToast(id: toastID)
            }
        }
        .navigationSplitViewStyle(.balanced)
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
                Task { await model.confirmPendingAction() }
            }
            Button(localizer.text(.cancel), role: .cancel) {
                model.cancelPendingAction()
            }
        } message: {
            if let action = model.pendingConfirmationAction {
                Text("\(localizer.string(action.titleKey)). \(localizer.text(.confirmRiskyMessage))")
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
            SettingsView()
                .environmentObject(settings)
        }
    }

    private var sidebar: some View {
        List(selection: Binding(
            get: { model.selectedDestination },
            set: { if let value = $0 { model.showDestination(value) } }
        )) {
            Section(localizer.text(.summaryTitle)) {
                Label(localizer.text(.panelDashboard), systemImage: "macwindow")
                    .tag(SidebarDestination.dashboard)
                Label(localizer.text(.activityTitle), systemImage: "bell.badge")
                    .tag(SidebarDestination.activity)
                Label(localizer.text(.logsTitle), systemImage: "terminal")
                    .tag(SidebarDestination.logs)
            }

            Section(localizer.text(.categories)) {
                ForEach(ActionCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.symbolName)
                        .tag(SidebarDestination.category(category))
                }
            }

            Section(localizer.text(.quickPanels)) {
                Label(localizer.text(.panelCPU), systemImage: "cpu")
                    .tag(SidebarDestination.cpu)
                Label(localizer.text(.panelMemory), systemImage: "memorychip")
                    .tag(SidebarDestination.memory)
                Label(localizer.text(.panelBattery), systemImage: "battery.75percent")
                    .tag(SidebarDestination.battery)
                Label(localizer.text(.panelMDM), systemImage: "building.2.crop.circle")
                    .tag(SidebarDestination.mdm)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(localizer.text(.appTitle))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch model.selectedDestination {
        case .dashboard:
            dashboardOverview
        case .activity:
            ActivityFeedView(
                localizer: localizer,
                filter: $model.activityFilter,
                items: model.filteredActivity
            )
        case .logs:
            LogsPanelView(localizer: localizer, output: model.debugOutput)
        case .category, .cpu, .memory, .battery, .mdm:
            categoryDetail
        }
    }

    private var dashboardOverview: some View {
        List {
            SystemInfoView(summary: model.machineSummary, localizer: localizer)

            Section(localizer.text(.actionsTitle)) {
                ForEach(model.actions.prefix(5)) { action in
                    ActionRowView(
                        action: action,
                        isRunning: model.isRunningActionID == action.id,
                        localizer: localizer,
                        density: settings.rowDensity
                    ) {
                        Task { await model.run(actionID: action.id) }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var categoryDetail: some View {
        List {
            SystemInfoView(summary: model.machineSummary, localizer: localizer)

            Section(localizer.text(.actionsTitle)) {
                ForEach(model.visibleActions) { action in
                    ActionRowView(
                        action: action,
                        isRunning: model.isRunningActionID == action.id,
                        localizer: localizer,
                        density: settings.rowDensity
                    ) {
                        Task { await model.run(actionID: action.id) }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}
