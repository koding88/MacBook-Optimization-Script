import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case vietnamese = "vi"

    var id: String { rawValue }
}

enum RefreshIntervalOption: String, CaseIterable, Identifiable {
    case manual
    case every5Minutes
    case every10Minutes
    case every30Minutes
    case every60Minutes

    var id: String { rawValue }

    var seconds: TimeInterval? {
        switch self {
        case .manual:
            return nil
        case .every5Minutes:
            return 300
        case .every10Minutes:
            return 600
        case .every30Minutes:
            return 1_800
        case .every60Minutes:
            return 3_600
        }
    }
}

enum RowDensity: String, CaseIterable, Identifiable {
    case comfortable
    case compact

    var id: String { rawValue }
}

final class AppSettingsStore: ObservableObject {
    static let allowedRefreshIntervalMinutes = [0, 5, 10, 30, 60]

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    @Published var refreshInterval: RefreshIntervalOption {
        didSet {
            guard !isSyncingRefreshSettings else { return }
            persistRefreshSettings(option: refreshInterval)
        }
    }

    @Published var refreshIntervalMinutes: Int {
        didSet {
            let normalizedMinutes = Self.clampedRefreshMinutes(refreshIntervalMinutes)
            guard !isSyncingRefreshSettings else { return }

            persistRefreshSettings(minutes: normalizedMinutes)
        }
    }

    @Published var showInspectorPanel: Bool {
        didSet { defaults.set(showInspectorPanel, forKey: Keys.showInspectorPanel) }
    }

    @Published var confirmPrivilegedActions: Bool {
        didSet { defaults.set(confirmPrivilegedActions, forKey: Keys.confirmPrivilegedActions) }
    }

    @Published var rowDensity: RowDensity {
        didSet { defaults.set(rowDensity.rawValue, forKey: Keys.rowDensity) }
    }

    private let defaults: UserDefaults
    private var isSyncingRefreshSettings = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedRefreshOption = RefreshIntervalOption(rawValue: defaults.string(forKey: Keys.refreshInterval) ?? "") ?? .every5Minutes
        let storedRefreshMinutes = defaults.object(forKey: Keys.refreshIntervalMinutes) as? Int
            ?? Self.minutes(for: storedRefreshOption)

        self.language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .english
        self.refreshInterval = Self.option(forMinutes: storedRefreshMinutes)
        self.refreshIntervalMinutes = Self.clampedRefreshMinutes(storedRefreshMinutes)
        self.showInspectorPanel = defaults.object(forKey: Keys.showInspectorPanel) as? Bool ?? true
        self.confirmPrivilegedActions = defaults.object(forKey: Keys.confirmPrivilegedActions) as? Bool ?? true
        self.rowDensity = RowDensity(rawValue: defaults.string(forKey: Keys.rowDensity) ?? "") ?? .comfortable
    }

    private func persistRefreshSettings(option: RefreshIntervalOption) {
        persistRefreshSettings(minutes: Self.minutes(for: option), option: option)
    }

    private func persistRefreshSettings(minutes: Int) {
        persistRefreshSettings(minutes: minutes, option: Self.option(forMinutes: minutes))
    }

    private func persistRefreshSettings(minutes: Int, option: RefreshIntervalOption) {
        let normalizedMinutes = Self.clampedRefreshMinutes(minutes)
        isSyncingRefreshSettings = true
        refreshIntervalMinutes = normalizedMinutes
        refreshInterval = option
        defaults.set(normalizedMinutes, forKey: Keys.refreshIntervalMinutes)
        defaults.set(option.rawValue, forKey: Keys.refreshInterval)
        isSyncingRefreshSettings = false
    }

    private static func clampedRefreshMinutes(_ minutes: Int) -> Int {
        let allowedMinutes = allowedRefreshIntervalMinutes
        guard let closest = allowedMinutes.min(by: { abs($0 - minutes) < abs($1 - minutes) }) else {
            return 0
        }
        return closest
    }

    private static func minutes(for option: RefreshIntervalOption) -> Int {
        switch option {
        case .manual:
            return 0
        case .every5Minutes:
            return 5
        case .every10Minutes:
            return 10
        case .every30Minutes:
            return 30
        case .every60Minutes:
            return 60
        }
    }

    private static func option(forMinutes minutes: Int) -> RefreshIntervalOption {
        switch clampedRefreshMinutes(minutes) {
        case 0:
            return .manual
        case 5:
            return .every5Minutes
        case 10:
            return .every10Minutes
        case 30:
            return .every30Minutes
        default:
            return .every60Minutes
        }
    }

    private enum Keys {
        static let language = "app.language"
        static let refreshInterval = "app.refreshInterval"
        static let refreshIntervalMinutes = "app.refreshIntervalMinutes"
        static let showInspectorPanel = "app.showInspectorPanel"
        static let confirmPrivilegedActions = "app.confirmPrivilegedActions"
        static let rowDensity = "app.rowDensity"
    }
}
