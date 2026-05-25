import XCTest
@testable import OnCue

final class AppSettingsTests: XCTestCase {
    func testLeadTimeClampSupportsNinetyMinuteReminders() {
        XCTAssertEqual(AppSettings.clampedLeadTime(90), 90)
    }

    func testLeadTimeClampKeepsValuesInsideSupportedRange() {
        XCTAssertEqual(AppSettings.clampedLeadTime(0), 1)
        XCTAssertEqual(AppSettings.clampedLeadTime(500), 120)
    }

    func testLeadTimeSettingCannotBeOutsideSupportedRange() {
        let settings = AppSettings(userDefaults: isolatedDefaults())

        settings.leadTimeMinutes = 0
        XCTAssertEqual(settings.leadTimeMinutes, 1)

        settings.leadTimeMinutes = 500
        XCTAssertEqual(settings.leadTimeMinutes, 120)

        settings.leadTimeMinutes = 90
        XCTAssertEqual(settings.leadTimeMinutes, 90)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "OnCueTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
