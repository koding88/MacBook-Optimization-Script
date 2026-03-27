import Foundation

struct ActionFeedbackPresenter: ActionFeedbackPresenting {
    let localizer: AppLocalizer

    func presentInspection(
        action: OptimizationAction,
        title: String,
        summaryLines: [String],
        symbolName: String? = nil
    ) -> ActionExecutionResult {
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
            summary: nil,
            debugLog: nil
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
                dismissAfter: isFailure ? nil : 3
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
