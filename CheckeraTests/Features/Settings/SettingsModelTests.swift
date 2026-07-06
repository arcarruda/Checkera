import Foundation
import Testing
@testable import Checkera

@MainActor
@Suite("SettingsModel")
struct SettingsModelTests {

    private func makeDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Defaults

    @Test("default regular tone is regularDefault")
    func defaultRegular() {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.regularTone == .regularDefault)
    }

    @Test("default golden tone is goldenBell")
    func defaultGolden() {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.goldenTone == .goldenBell)
    }

    @Test("default theme preference is system")
    func defaultTheme() {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.themePreference == .system)
    }

    // MARK: - Persistence

    @Test("setting regular tone persists to defaults")
    func setRegularPersists() {
        let defaults = makeDefaults()
        let model = SettingsModel(defaults: defaults)

        model.regularTone = .regularChime

        #expect(defaults.string(forKey: "regularTone") == NotificationTone.regularChime.rawValue)
    }

    @Test("setting golden tone persists to defaults")
    func setGoldenPersists() {
        let defaults = makeDefaults()
        let model = SettingsModel(defaults: defaults)

        model.goldenTone = .goldenFanfare

        #expect(defaults.string(forKey: "goldenTone") == NotificationTone.goldenFanfare.rawValue)
    }

    @Test("model loads existing values from defaults")
    func loadsExisting() {
        let defaults = makeDefaults()
        defaults.set(NotificationTone.regularSubtle.rawValue, forKey: "regularTone")
        defaults.set(NotificationTone.goldenChime.rawValue, forKey: "goldenTone")

        let model = SettingsModel(defaults: defaults)

        #expect(model.regularTone == .regularSubtle)
        #expect(model.goldenTone == .goldenChime)
    }

    @Test("setting theme preference persists to defaults")
    func setThemePersists() {
        let defaults = makeDefaults()
        let model = SettingsModel(defaults: defaults)

        model.themePreference = .dark

        #expect(defaults.string(forKey: "themePreference") == ThemePreference.dark.rawValue)
    }

    @Test("model loads existing theme preference from defaults")
    func loadsExistingTheme() {
        let defaults = makeDefaults()
        defaults.set(ThemePreference.light.rawValue, forKey: "themePreference")

        let model = SettingsModel(defaults: defaults)

        #expect(model.themePreference == .light)
    }

    // MARK: - tone(for:)

    @Test("tone(for: .regular) returns the regular tone")
    func toneForRegular() {
        let model = SettingsModel(defaults: makeDefaults())
        model.regularTone = .regularSubtle

        #expect(model.tone(for: .regular) == .regularSubtle)
    }

    @Test("tone(for: .golden) returns the golden tone")
    func toneForGolden() {
        let model = SettingsModel(defaults: makeDefaults())
        model.goldenTone = .goldenFanfare

        #expect(model.tone(for: .golden) == .goldenFanfare)
    }

    // MARK: - Sleep window — defaults

    @Test("default wakeUpMinute is 6:00 AM (360)")
    func defaultWakeUp() {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.wakeUpMinute == 360)
    }

    @Test("default bedTimeMinute is 11:00 PM (1380)")
    func defaultBedTime() {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.bedTimeMinute == 1380)
    }

    @Test("default sleepWindow matches SleepWindow.default")
    func defaultSleepWindow() {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.sleepWindow == SleepWindow.default)
    }

    // MARK: - Sleep window — persistence

    @Test("setting wakeUpMinute persists to defaults")
    func setWakeUpPersists() {
        let defaults = makeDefaults()
        let model = SettingsModel(defaults: defaults)

        model.wakeUpMinute = 450

        #expect(defaults.integer(forKey: "wakeUpMinute") == 450)
    }

    @Test("setting bedTimeMinute persists to defaults")
    func setBedTimePersists() {
        let defaults = makeDefaults()
        let model = SettingsModel(defaults: defaults)

        model.bedTimeMinute = 1320

        #expect(defaults.integer(forKey: "bedTimeMinute") == 1320)
    }

    @Test("model loads existing sleep window from defaults")
    func loadsExistingSleepWindow() {
        let defaults = makeDefaults()
        defaults.set(420, forKey: "wakeUpMinute")
        defaults.set(1320, forKey: "bedTimeMinute")

        let model = SettingsModel(defaults: defaults)

        #expect(model.wakeUpMinute == 420)
        #expect(model.bedTimeMinute == 1320)
    }

    // MARK: - Date <-> minutes

    @Test("date(fromMinutesFromMidnight:) returns the matching hour and minute")
    func dateFromMinutes() {
        let date = SettingsModel.date(fromMinutesFromMidnight: 450)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        #expect(comps.hour == 7)
        #expect(comps.minute == 30)
    }

    @Test("minutesFromMidnight(of:) round-trips with date(fromMinutesFromMidnight:)")
    func roundTrip() {
        let original = 7 * 60 + 45
        let date = SettingsModel.date(fromMinutesFromMidnight: original)
        #expect(SettingsModel.minutesFromMidnight(of: date) == original)
    }
}
