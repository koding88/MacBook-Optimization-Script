import Foundation

struct SettingsFormatter {
    let localizer: AppLocalizer

    func autoRefreshDescription(minutes: Int) -> String {
        if minutes == 0 {
            return localizer.text(.refreshManual)
        }

        if minutes == 1 {
            return localizer.text(.refresh1m)
        }

        let format = localizer.string("settings.refresh.minutesFormat")
        return String(format: format, locale: Locale(identifier: localizer.language.rawValue), minutes)
    }
}
