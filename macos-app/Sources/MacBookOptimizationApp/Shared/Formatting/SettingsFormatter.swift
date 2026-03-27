import Foundation

struct SettingsFormatter {
    let localizer: AppLocalizer

    func autoRefreshDescription(minutes: Int) -> String {
        switch minutes {
        case 0:
            return localizer.text(.refreshManual)
        case 5:
            return localizer.text(.refresh5m)
        case 10:
            return localizer.text(.refresh10m)
        case 30:
            return localizer.text(.refresh30m)
        case 60:
            return localizer.text(.refresh60m)
        default:
            let format = localizer.text(.refreshMinutesFormat)
            return String(format: format, locale: Locale(identifier: localizer.language.rawValue), minutes)
        }
    }

    func autoRefreshStatus(minutes: Int) -> String {
        String(
            format: localizer.text(.refreshStatusFormat),
            locale: Locale(identifier: localizer.language.rawValue),
            autoRefreshDescription(minutes: minutes)
        )
    }
}
