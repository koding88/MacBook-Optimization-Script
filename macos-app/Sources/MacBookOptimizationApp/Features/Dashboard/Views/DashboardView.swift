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
        DashboardSidebarView(
            title: localizer.text(.appTitle),
            selectedDestination: model.selectedDestination,
            onSelect: model.showDestination,
            summaryTitle: localizer.text(.summaryTitle),
            categoriesTitle: localizer.text(.categories),
            quickPanelsTitle: localizer.text(.quickPanels),
            summaryItems: [
                .item(title: localizer.text(.panelDashboard), systemImage: "macwindow", destination: .dashboard),
                .item(title: localizer.text(.panelAllStatuses), systemImage: "list.bullet.rectangle", destination: .statuses),
                .item(title: localizer.text(.activityTitle), systemImage: "bell.badge", destination: .activity),
                .item(title: localizer.text(.logsTitle), systemImage: "terminal", destination: .logs)
            ],
            categoryItems: ActionCategory.allCases.map {
                .item(
                    title: localizer.text($0.localizedKey),
                    systemImage: $0.symbolName,
                    destination: .category($0)
                )
            },
            quickPanelItems: [
                .item(title: localizer.text(.panelCPU), systemImage: "cpu", destination: .cpu),
                .item(title: localizer.text(.panelGPU), systemImage: "display.2", destination: .gpu),
                .item(title: localizer.text(.panelMemory), systemImage: "memorychip", destination: .memory),
                .item(title: localizer.text(.panelBattery), systemImage: "battery.75percent", destination: .battery),
                .item(title: localizer.text(.panelMDM), systemImage: "building.2.crop.circle", destination: .mdm)
            ]
        )
        .navigationTitle(localizer.text(.appTitle))
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

private struct SidebarItemDefinition: Identifiable {
    let title: String
    let systemImage: String
    let destination: SidebarDestination
    let accentColor: Color

    var id: SidebarDestination { destination }
}

private extension SidebarDestination {
    var sidebarAccentColor: Color {
        switch self {
        case .dashboard:
            return .blue
        case .statuses:
            return Color(nsColor: .systemBlue).opacity(0.8)
        case .activity:
            return Color(nsColor: .systemOrange)
        case .logs:
            return Color(nsColor: .systemGray)
        case .category(let category):
            switch category {
            case .system:
                return Color(nsColor: .systemIndigo).opacity(0.75)
            case .network:
                return .cyan
            case .storage:
                return .teal
            case .performance:
                return .purple
            case .maintenance:
                return .orange
            case .monitoring:
                return .green
            }
        case .cpu:
            return .blue
        case .gpu:
            return Color(nsColor: .systemIndigo)
        case .memory:
            return .purple
        case .battery:
            return .green
        case .mdm:
            return Color(nsColor: .systemGray)
        }
    }
}

private extension SidebarItemDefinition {
    static func item(title: String, systemImage: String, destination: SidebarDestination) -> SidebarItemDefinition {
        SidebarItemDefinition(
            title: title,
            systemImage: systemImage,
            destination: destination,
            accentColor: destination.sidebarAccentColor
        )
    }
}

private extension Color {
    static let sidebarSurface = Color(nsColor: NSColor.windowBackgroundColor).opacity(0.9)
    static let sidebarHeaderSurface = Color.white.opacity(0.55)
    static let sidebarHoverFill = Color.black.opacity(0.045)
    static let sidebarTitleColor = Color(nsColor: .secondaryLabelColor)
    static let sidebarTextColor = Color(nsColor: .secondaryLabelColor)
    static let sidebarIconNeutral = Color(nsColor: .secondaryLabelColor).opacity(0.92)
    static let sidebarSelectionBlue = Color(nsColor: NSColor(calibratedRed: 0.44, green: 0.66, blue: 0.96, alpha: 1))
}

private extension ShapeStyle where Self == AnyShapeStyle {
    static func sidebarSelectionFill(accentColor: Color) -> AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    accentColor.opacity(0.18),
                    Color.sidebarSelectionBlue.opacity(0.11)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

private extension SidebarItemDefinition {
    var selectedIconColor: Color {
        accentColor
    }
}

private extension SidebarDestination {
    var selectedPillColor: AnyShapeStyle {
        .sidebarSelectionFill(accentColor: sidebarAccentColor)
    }
}

private extension SidebarItemDefinition {
    var selectedPillColor: AnyShapeStyle {
        destination.selectedPillColor
    }
}

private extension SidebarItemDefinition {
    var selectedTextColor: Color {
        Color(nsColor: .labelColor)
    }
}

private extension SidebarItemDefinition {
    var inactiveTextColor: Color {
        .sidebarTextColor
    }
}

private extension SidebarItemDefinition {
    var inactiveIconColor: Color {
        .sidebarIconNeutral
    }
}

private extension SidebarItemDefinition {
    var hoverFillColor: Color {
        accentColor.opacity(0.08)
    }
}

private extension SidebarItemDefinition {
    var selectionBorderColor: Color {
        Color.white.opacity(0.32)
    }
}

private extension SidebarItemDefinition {
    var selectionShadowColor: Color {
        accentColor.opacity(0.10)
    }
}

private extension SidebarItemDefinition {
    var hoverScale: CGFloat { 1.008 }
}

private extension SidebarItemDefinition {
    var rowCornerRadius: CGFloat { 13 }
}

private extension SidebarItemDefinition {
    var titleTracking: CGFloat { 0.2 }
}

private extension SidebarItemDefinition {
    var groupLabelColor: Color { .sidebarTitleColor }
}

private extension SidebarItemDefinition {
    var selectedPillInsetShadow: Color { Color.white.opacity(0.18) }
}

private extension SidebarItemDefinition {
    var headerDividerColor: Color { Color.black.opacity(0.06) }
}

private extension SidebarItemDefinition {
    var headerMaterialOverlay: Color { Color.white.opacity(0.42) }
}

private extension SidebarItemDefinition {
    var surfaceStrokeColor: Color { Color.white.opacity(0.30) }
}

private extension SidebarItemDefinition {
    var surfaceShadowColor: Color { Color.black.opacity(0.04) }
}

private extension SidebarItemDefinition {
    var titleFontSize: CGFloat { 18 }
}

private extension SidebarItemDefinition {
    var sectionLabelFontSize: CGFloat { 10.5 }
}

private extension SidebarItemDefinition {
    var rowFontSize: CGFloat { 13 }
}

private extension SidebarItemDefinition {
    var iconFontSize: CGFloat { 14 }
}

private extension SidebarItemDefinition {
    var iconFrameWidth: CGFloat { 18 }
}

private extension SidebarItemDefinition {
    var rowHorizontalPadding: CGFloat { 10 }
}

private extension SidebarItemDefinition {
    var rowVerticalPadding: CGFloat { 8 }
}

private extension SidebarItemDefinition {
    var rowSpacing: CGFloat { 10 }
}

private extension SidebarItemDefinition {
    var sectionItemSpacing: CGFloat { 3 }
}

private extension SidebarItemDefinition {
    var sectionSpacing: CGFloat { 18 }
}

private extension SidebarItemDefinition {
    var containerHorizontalPadding: CGFloat { 10 }
}

private extension SidebarItemDefinition {
    var titleHorizontalPadding: CGFloat { 14 }
}

private struct DashboardSidebarView: View {
    let title: String
    let selectedDestination: SidebarDestination
    let onSelect: (SidebarDestination) -> Void
    let summaryTitle: String
    let categoriesTitle: String
    let quickPanelsTitle: String
    let summaryItems: [SidebarItemDefinition]
    let categoryItems: [SidebarItemDefinition]
    let quickPanelItems: [SidebarItemDefinition]

    @Namespace private var selectionNamespace

    private let selectionAnimation = Animation.easeOut(duration: 0.18)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sidebarGroup(title: summaryTitle, items: summaryItems)
                sidebarGroup(title: categoriesTitle, items: categoryItems)
                sidebarGroup(title: quickPanelsTitle, items: quickPanelItems)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
        .background(Color.sidebarSurface)
    }

    private func sidebarGroup(title: String, items: [SidebarItemDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.sidebarTitleColor)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(items) { item in
                    DashboardSidebarRow(
                        item: item,
                        isSelected: selectedDestination == item.destination,
                        namespace: selectionNamespace,
                        selectionAnimation: selectionAnimation
                    ) {
                        withAnimation(selectionAnimation) {
                            onSelect(item.destination)
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardSidebarRow: View {
    let item: SidebarItemDefinition
    let isSelected: Bool
    let namespace: Namespace.ID
    let selectionAnimation: Animation
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .symbolVariant(isSelected ? .fill : .none)
                    .foregroundStyle(iconColor)
                    .frame(width: 18)

                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .background(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(selectionFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(item.selectionBorderColor, lineWidth: 0.6)
                        }
                        .shadow(color: item.selectionShadowColor, radius: 10, y: 3)
                        .matchedGeometryEffect(id: "sidebar-selection-pill", in: namespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(item.hoverFillColor)
                }
            }
            .scaleEffect(1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private var textColor: Color {
        isSelected ? item.selectedTextColor : item.inactiveTextColor
    }

    private var iconColor: Color {
        isSelected ? item.selectedIconColor : item.inactiveIconColor
    }

    private var selectionFill: some ShapeStyle {
        item.selectedPillColor
    }
}
