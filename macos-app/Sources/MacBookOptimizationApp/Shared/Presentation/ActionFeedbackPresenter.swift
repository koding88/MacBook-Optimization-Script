import Foundation

struct ActionFeedbackPresenter: ActionFeedbackPresenting {
    let localizer: AppLocalizer

    func presentInspection(
        action: OptimizationAction,
        summary: ActionResultSummary,
        debugLog: String?,
        symbolName: String? = nil
    ) -> ActionExecutionResult {
        let title = localizer.string(action.titleKey)
        let summaryLines = [summary.primaryValue] + summary.secondaryValues.map {
            "\(localizer.text($0.labelKey)): \($0.value)"
        }
        let cappedSummaryLines = Array(summaryLines.prefix(3))
        let activityMessage = cappedSummaryLines.joined(separator: " • ")

        return ActionExecutionResult(
            status: .enabled,
            toast: ToastMessage(
                type: .success,
                title: title,
                message: localizer.inspectionToastMessage(title: title),
                summaryLines: cappedSummaryLines,
                dismissAfter: 3
            ),
            activityEvent: ActivityEvent(
                type: .success,
                title: title,
                message: activityMessage,
                symbolName: symbolName ?? action.symbolName
            ),
            summary: summary,
            debugLog: debugLog
        )
    }

    func presentMutation(
        action: OptimizationAction,
        status: ActionStatus,
        debugLog: String?
    ) -> ActionExecutionResult {
        let title = localizer.string(action.titleKey)
        let isFailure = status == .failed
        let toastType: ToastType = isFailure ? .error : .success
        let activityType: ActivityEventType = isFailure ? .error : .success
        let message = isFailure
            ? "\(title) needs attention. Review the debug log for details."
            : "\(title) completed successfully."

        return ActionExecutionResult(
            status: status,
            toast: ToastMessage(
                type: toastType,
                title: title,
                message: message,
                dismissAfter: isFailure ? 7 : 3
            ),
            activityEvent: ActivityEvent(
                type: activityType,
                title: title,
                message: message,
                symbolName: action.symbolName
            ),
            summary: nil,
            debugLog: debugLog
        )
    }
}
