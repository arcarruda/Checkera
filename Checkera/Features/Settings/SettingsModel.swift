import Foundation
import SwiftUI
import os

@MainActor
@Observable
final class SettingsModel {

    // MARK: - Stored

    /// One tone per task colour. Written through `setTone(_:for:)`, which persists each entry
    /// under its own key so a new colour never disturbs the others.
    private(set) var tonesByColor: [TaskColor: NotificationTone]

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

    // Pre-palette keys. Still read so that upgrading users keep the tones they already chose.
    private static let regularKey = "regularTone"
    private static let goldenKey = "goldenTone"
    private static let themeKey = "themePreference"
    private static let wakeUpKey = "wakeUpMinute"
    private static let bedTimeKey = "bedTimeMinute"

    static func toneKey(for color: TaskColor) -> String { "tone.\(color.rawValue)" }

    // MARK: - Init

    init(defaults: UserDefaults = SettingsModel.sharedDefaults) {
        self.defaults = defaults
        self.tonesByColor = Self.loadTones(from: defaults)
        self.themePreference = ThemePreference(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .system
        self.wakeUpMinute = defaults.object(forKey: Self.wakeUpKey) as? Int ?? SleepWindow.default.wakeUpMinute
        self.bedTimeMinute = defaults.object(forKey: Self.bedTimeKey) as? Int ?? SleepWindow.default.bedTimeMinute
    }

    private static func loadTones(from defaults: UserDefaults) -> [TaskColor: NotificationTone] {
        var result: [TaskColor: NotificationTone] = [:]
        for color in TaskColor.allCases {
            // Per-colour key first, then the pre-palette key this colour inherits from.
            let legacyKey = color.isAlarm ? goldenKey : regularKey
            let raw = defaults.string(forKey: toneKey(for: color))
                ?? defaults.string(forKey: legacyKey)
                ?? ""
            result[color] = sanitized(NotificationTone(rawValue: raw), for: color)
        }
        return result
    }

    /// Keeps a colour's tone in its own category.
    ///
    /// Tones persist as raw strings, so a stale or hand-edited value could pair a non-alarm
    /// colour with a golden tone — and `NotificationService` derives nothing from the tone's
    /// category any more, but the Settings picker would show an option that isn't in its list.
    private static func sanitized(_ tone: NotificationTone?, for color: TaskColor) -> NotificationTone {
        guard let tone, (tone.category == .golden) == color.isAlarm else { return color.defaultTone }
        return tone
    }

    // MARK: - Lookup

    func tone(for color: TaskColor) -> NotificationTone {
        Self.sanitized(tonesByColor[color], for: color)
    }

    func setTone(_ tone: NotificationTone, for color: TaskColor) {
        let clean = Self.sanitized(tone, for: color)
        tonesByColor[color] = clean
        defaults.set(clean.rawValue, forKey: Self.toneKey(for: color))
    }

    func toneBinding(for color: TaskColor) -> Binding<NotificationTone> {
        Binding(
            get: { self.tone(for: color) },
            set: { self.setTone($0, for: color) }
        )
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
