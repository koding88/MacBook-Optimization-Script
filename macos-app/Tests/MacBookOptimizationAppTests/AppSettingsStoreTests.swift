import XCTest
@testable import MacBookOptimizationApp

final class AppSettingsStoreTests: XCTestCase {
    func testRefreshMinutesPersistAsIntegerValue() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppSettingsStore(defaults: defaults)
        store.refreshIntervalMinutes = 5

        let reloaded = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.refreshIntervalMinutes, 5)
    }

    func testAutoRefreshDescriptionUsesFormatterForMinuteValues() {
        let formatter = SettingsFormatter(localizer: AppLocalizer(language: .english))

        let value = formatter.autoRefreshDescription(minutes: 5)

        XCTAssertEqual(value, "Every 5 minutes")
    }

    func testRefreshMinutesClampToAllowedPreset() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = AppSettingsStore(defaults: defaults)
        store.refreshIntervalMinutes = 12

        XCTAssertEqual(store.refreshIntervalMinutes, 10)
        XCTAssertEqual(store.refreshInterval, .every10Minutes)
    }
}
