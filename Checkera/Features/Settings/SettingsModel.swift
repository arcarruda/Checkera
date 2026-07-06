import Foundation
import os

@MainActor
@Observable
final class SettingsModel {

    // MARK: - Stored

    var regularTone: NotificationTone {
        didSet { defaults.set(regularTone.rawValue, forKey: Self.regularKey) }
    }

    var goldenTone: NotificationTone {
        didSet { defaults.set(goldenTone.rawValue, forKey: Self.goldenKey) }
    }

    var themePreference: ThemePreference {
        didSet { defaults.set(themePreference.rawValue, forKey: Self.themeKey) }
    }

    var wakeUpMinute: Int {
        didSet { defaults.set(wakeUpMinute, forKey: Self.wakeUpKey) }
    }

    var bedTimeMinute: Int {
        didSet { defaults.set(bedTimeMinute, forKey: Self.bedTimeKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: "app.checkera", category: "Settings")

    private static let regularKey = "regularTone"
    private static let goldenKey = "goldenTone"
    private static let themeKey = "themePreference"
    private static let wakeUpKey = "wakeUpMinute"
    private static let bedTimeKey = "bedTimeMinute"

    // MARK: - Init

    init(defaults: UserDefaults = SettingsModel.sharedDefaults) {
        self.defaults = defaults
        self.regularTone = NotificationTone(rawValue: defaults.string(forKey: Self.regularKey) ?? "") ?? .regularDefault
        self.goldenTone = NotificationTone(rawValue: defaults.string(forKey: Self.goldenKey) ?? "") ?? .goldenBell
        self.themePreference = ThemePreference(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .system
        self.wakeUpMinute = defaults.object(forKey: Self.wakeUpKey) as? Int ?? SleepWindow.default.wakeUpMinute
        self.bedTimeMinute = defaults.object(forKey: Self.bedTimeKey) as? Int ?? SleepWindow.default.bedTimeMinute
    }

    // MARK: - Lookup

    func tone(for type: TaskType) -> NotificationTone {
        switch type {
        case .regular: regularTone
        case .golden: goldenTone
        }
    }

    var sleepWindow: SleepWindow {
        SleepWindow(wakeUpMinute: wakeUpMinute, bedTimeMinute: bedTimeMinute)
    }

    // MARK: - Date <-> minutes

    static func date(fromMinutesFromMidnight minutes: Int, calendar: Calendar = .current, reference: Date = .now) -> Date {
        let bounded = max(0, min(SleepWindow.minutesPerDay - 1, minutes))
        let hour = bounded / 60
        let minute = bounded % 60
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: reference) ?? reference
    }

    static func minutesFromMidnight(of date: Date, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    // MARK: - Defaults source

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: PersistenceController.appGroupIdentifier) ?? .standard
    }
}
