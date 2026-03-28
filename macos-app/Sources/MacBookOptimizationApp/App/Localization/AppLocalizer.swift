import Foundation

enum LocalizedKey: String {
    case appTitle = "app.title"
    case categories = "sidebar.categories"
    case quickPanels = "sidebar.quickPanels"
    case summaryTitle = "detail.summary"
    case actionsTitle = "detail.actions"
    case activityTitle = "inspector.activity"
    case logsTitle = "inspector.logs"
    case settingsTitle = "settings.title"
    case manualRefresh = "toolbar.refresh"
    case openSettings = "toolbar.settings"
    case toggleInspector = "toolbar.inspector"
    case statusCompleted = "status.completed"
    case statusRunning = "status.running"
    case statusAttention = "status.attention"
    case statusCatalog = "status.catalog"
    case statusReady = "status.ready"
    case statusEnabled = "status.enabled"
    case statusFailed = "status.failed"
    case statusNeedsReview = "status.needsReview"
    case run = "action.run"
    case privileged = "action.privileged"
    case requiresRestart = "action.requiresRestart"
    case riskyAction = "action.risky"
    case safeAction = "action.safe"
    case lastRun = "action.lastRun"
    case noData = "common.noData"
    case confirmRiskyTitle = "confirm.title"
    case confirmRiskyMessage = "confirm.message"
    case continueAction = "confirm.continue"
    case cancel = "common.cancel"
    case done = "common.done"
    case englishLanguage = "common.language.english"
    case vietnameseLanguage = "common.language.vietnamese"
    case unavailable = "common.unavailable"
    case generalSection = "settings.general"
    case languageSection = "settings.language.section"
    case refreshSection = "settings.refresh.section"
    case appearanceSection = "settings.appearance.section"
    case safetySection = "settings.safety.section"
    case languageLabel = "settings.language.label"
    case refreshIntervalLabel = "settings.refresh.interval"
    case showInspectorLabel = "settings.inspector.default"
    case confirmPrivilegedLabel = "settings.safety.confirmPrivileged"
    case rowDensityLabel = "settings.density.label"
    case rowDensityComfortable = "settings.density.comfortable"
    case rowDensityCompact = "settings.density.compact"
    case refreshStatusFormat = "settings.refresh.statusFormat"
    case refreshManual = "settings.refresh.manual"
    case refresh5m = "settings.refresh.5m"
    case refresh10m = "settings.refresh.10m"
    case refresh30m = "settings.refresh.30m"
    case refresh60m = "settings.refresh.60m"
    case refreshMinutesFormat = "settings.refresh.minutesFormat"
    case activityFilterLabel = "activity.filter.label"
    case activityFilterHelp = "activity.filter.help"
    case activityFilterAll = "activity.filter.all"
    case activityFilterLast5Minutes = "activity.filter.last5Minutes"
    case activityFilterLastHour = "activity.filter.lastHour"
    case activityFilterToday = "activity.filter.today"
    case storageAvailableSuffix = "system.storage.availableSuffix"
    case systemLabelChip = "system.label.chip"
    case systemLabelCPU = "system.label.cpu"
    case systemLabelMemory = "system.label.memory"
    case systemLabelStorage = "system.label.storage"
    case systemLabelDisplay = "system.label.display"
    case systemLabelBattery = "system.label.battery"
    case systemLabelMacOS = "system.label.macos"
    case panelDashboard = "panel.dashboard"
    case panelAllStatuses = "panel.statuses"
    case panelCPU = "panel.cpu"
    case panelMemory = "panel.memory"
    case panelBattery = "panel.battery"
    case panelMDM = "panel.mdm"
    case metadataEstimate = "metadata.estimate"
    case metadataPrivilege = "metadata.privilege"
    case metadataRestart = "metadata.restart"
    case metadataRisk = "metadata.risk"
    case snapshotCPUCores = "snapshot.cpu.cores"
    case snapshotCPUUsage = "snapshot.cpu.usage"
    case inspectionToastMessage = "inspection.toast.message"
    case appReadyTitle = "activity.appReady.title"
    case appReadyMessage = "activity.appReady.message"
    case actionCancelledTitle = "activity.actionCancelled.title"
    case actionCancelledMessage = "activity.actionCancelled.message"
    case privilegedPromptTitle = "activity.privilegedPrompt.title"
    case privilegedPromptMessage = "activity.privilegedPrompt.message"
    case privilegedPromptToastTitle = "toast.privilegedPrompt.title"
    case privilegedPromptToastMessage = "toast.privilegedPrompt.message"
    case administratorCancelledTitle = "activity.administratorCancelled.title"
    case administratorCancelledMessage = "activity.administratorCancelled.message"
    case statusRefreshedTitle = "activity.statusRefreshed.title"
    case statusRefreshedMessage = "activity.statusRefreshed.message"
    case runningActionTitle = "activity.runningAction.title"
    case runningActionMessage = "activity.runningAction.message"
    case actionFailedTitle = "activity.actionFailed.title"
    case actionFailedMessage = "activity.actionFailed.message"
    case actionFailedAdministratorMessage = "activity.actionFailedAdministrator.message"
    case systemReviewTitle = "system.review.title"
    case systemReviewMessage = "system.review.message"
    case systemReviewStepCount = "system.review.stepCount"
    case systemReviewSelectAll = "system.review.selectAll"
    case systemReviewClearAll = "system.review.clearAll"
    case systemReviewRunSelected = "system.review.runSelected"
    case systemReviewCommandLabel = "system.review.commandLabel"
    case systemReviewAdminBadge = "system.review.adminBadge"
    case systemReviewStepFallbackTitle = "system.review.stepFallback.title"
    case systemReviewStepFallbackDetail = "system.review.stepFallback.detail"
    case statusLoadFailedTitle = "activity.statusLoadFailed.title"
    case statusLoadFailedMessage = "activity.statusLoadFailed.message"
    case actionCompletedWithoutOutput = "logs.noOutputMessage"
    case noOptimizationsYet = "logs.noOptimizationsYet"
    case detailSummary = "detail.summary.label"
    case noLogsYet = "inspector.noLogs"
    case noOutputYet = "inspector.noOutput"
}

struct AppLocalizer {
    let language: AppLanguage

    func text(_ key: LocalizedKey) -> String {
        string(key.rawValue)
    }

    func string(_ key: String) -> String {
        NSLocalizedString(
            key,
            tableName: "Localizable",
            bundle: bundle,
            value: key,
            comment: ""
        )
    }

    func format(_ key: LocalizedKey, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    func inspectionToastMessage(title: String) -> String {
        format(.inspectionToastMessage, title)
    }

    private var bundle: Bundle {
        guard let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .module
        }
        return bundle
    }

    private var locale: Locale {
        Locale(identifier: language.rawValue)
    }
}
