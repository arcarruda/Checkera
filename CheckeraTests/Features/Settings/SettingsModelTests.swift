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

    @Test("every color defaults to its own default tone", arguments: TaskColor.allCases)
    func defaultTonePerColor(_ color: TaskColor) {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.tone(for: color) == color.defaultTone)
    }

    @Test("gold defaults to goldenBell, other colors to regularDefault")
    func defaultTonesByCategory() {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.tone(for: .gold) == .goldenBell)
        #expect(model.tone(for: .blue) == .regularDefault)
    }

    @Test("default theme preference is system")
    func defaultTheme() {
        let model = SettingsModel(defaults: makeDefaults())
        #expect(model.themePreference == .system)
    }

    // MARK: - Persistence

    @Test("setting a color's tone persists under that color's own key")
    func setTonePersists() {
        let defaults = makeDefaults()
        let model = SettingsModel(defaults: defaults)

        model.setTone(.regularChime, for: .teal)

        #expect(defaults.string(forKey: "tone.teal") == NotificationTone.regularChime.rawValue)
        #expect(model.tone(for: .teal) == .regularChime)
        // Sibling colours are untouched.
        #expect(model.tone(for: .blue) == .regularDefault)
    }

    @Test("model loads existing per-color tones from defaults")
    func loadsExistingPerColor() {
        let defaults = makeDefaults()
        defaults.set(NotificationTone.regularSubtle.rawValue, forKey: "tone.purple")
        defaults.set(NotificationTone.goldenChime.rawValue, forKey: "tone.gold")

        let model = SettingsModel(defaults: defaults)

        #expect(model.tone(for: .purple) == .regularSubtle)
        #expect(model.tone(for: .gold) == .goldenChime)
    }

    // MARK: - Upgrading from the pre-palette keys

    @Test("pre-palette goldenTone still applies to gold")
    func legacyGoldenKeyInherited() {
        let defaults = makeDefaults()
        defaults.set(NotificationTone.goldenFanfare.rawValue, forKey: "goldenTone")

        let model = SettingsModel(defaults: defaults)

        #expect(model.tone(for: .gold) == .goldenFanfare)
    }

    @Test("pre-palette regularTone still applies to every non-gold color")
    func legacyRegularKeyInherited() {
        let defaults = makeDefaults()
        defaults.set(NotificationTone.regularSubtle.rawValue, forKey: "regularTone")

        let model = SettingsModel(defaults: defaults)

        for color in TaskColor.allCases where !color.isAlarm {
            #expect(model.tone(for: color) == .regularSubtle)
        }
        #expect(model.tone(for: .gold) == .goldenBell)
    }

    @Test("a per-color key wins over the pre-palette key")
    func perColorKeyWins() {
        let defaults = makeDefaults()
        defaults.set(NotificationTone.regularSubtle.rawValue, forKey: "regularTone")
        defaults.set(NotificationTone.regularChime.rawValue, forKey: "tone.pink")

        let model = SettingsModel(defaults: defaults)

        #expect(model.tone(for: .pink) == .regularChime)
        #expect(model.tone(for: .blue) == .regularSubtle)
    }

    // MARK: - Category guard

    @Test("a stored tone from the wrong category falls back to the color's default")
    func mismatchedCategoryIsRejected() {
        let defaults = makeDefaults()
        defaults.set(NotificationTone.goldenBell.rawValue, forKey: "tone.teal")
        defaults.set(NotificationTone.regularChime.rawValue, forKey: "tone.gold")

        let model = SettingsModel(defaults: defaults)

        #expect(model.tone(for: .teal) == .regularDefault)
        #expect(model.tone(for: .gold) == .goldenBell)
    }

    @Test("setTone refuses a tone from the wrong category")
    func setToneRejectsMismatch() {
        let defaults = makeDefaults()
        let model = SettingsModel(defaults: defaults)

        model.setTone(.goldenFanfare, for: .red)

        #expect(model.tone(for: .red) == .regularDefault)
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

    @Test("tone(for:) returns what was set for that color")
    func toneForColor() {
        let model = SettingsModel(defaults: makeDefaults())

        model.setTone(.regularSubtle, for: .purple)
        model.setTone(.goldenFanfare, for: .gold)

        #expect(model.tone(for: .purple) == .regularSubtle)
        #expect(model.tone(for: .gold) == .goldenFanfare)
    }

    @Test("toneBinding writes through to the model")
    func toneBindingWrites() {
        let model = SettingsModel(defaults: makeDefaults())

        model.toneBinding(for: .pink).wrappedValue = .regularChime

        #expect(model.tone(for: .pink) == .regularChime)
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
