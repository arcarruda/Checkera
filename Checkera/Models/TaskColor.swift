import Foundation

/// The user-selectable colour of a task.
///
/// A colour is a *flavour*, not just a tint: it decides how the task is drawn **and** which
/// notification tone it plays. `gold` is the one flavour that alarms — it keeps the
/// time-sensitive category with snooze actions that the old `TaskType.golden` had.
///
/// Raw values are persisted in `DailyTask.colorRaw` and are therefore user data — renaming a
/// case orphans every task using it to the `.blue` fallback. `TaskColorTests` locks them down.
///
/// Kept Foundation-only so the widget target can compile it; the SwiftUI rendering lives in
/// `TaskColor+Style.swift`, which is app-only.
enum TaskColor: String, Codable, CaseIterable, Sendable, Identifiable {
    // Declaration order is the palette's display order everywhere (it drives `allCases`).
    // Gold sits last because it is the only colour that changes behaviour — the plain
    // reminder colours read first, then the one that alarms. Reordering is safe:
    // `DailyTask.colorRaw` persists the rawValue string, never the case position.
    case blue
    case teal
    case green
    case orange
    case red
    case purple
    case pink
    case gold

    var id: String { rawValue }

    /// The colour applied to tasks that predate the palette, and to anything unrecognised.
    static let fallback: TaskColor = .blue

    /// Only gold alarms: time-sensitive delivery, snooze + dismiss actions.
    var isAlarm: Bool { self == .gold }

    /// The legacy `TaskType` this colour corresponds to.
    ///
    /// `typeRaw` is still written on every save so that downgrading to a build without the
    /// palette keeps golden tasks golden.
    var alarmType: TaskType { isAlarm ? .golden : .regular }

    /// The tone used until the user picks one for this colour in Settings.
    var defaultTone: NotificationTone { isAlarm ? .goldenBell : .regularDefault }

    /// Name of the colour set in `Assets.xcassets`.
    var assetName: String {
        switch self {
        case .blue: "TaskBlue"
        case .teal: "TaskTeal"
        case .green: "TaskGreen"
        case .gold: "TaskGold"
        case .orange: "TaskOrange"
        case .red: "TaskRed"
        case .purple: "TaskPurple"
        case .pink: "TaskPink"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .blue: "Blue"
        case .teal: "Teal"
        case .green: "Green"
        case .gold: "Gold"
        case .orange: "Orange"
        case .red: "Red"
        case .purple: "Purple"
        case .pink: "Pink"
        }
    }

    /// Short description of what the colour does to notifications, shown next to the picker.
    var behaviorDescription: LocalizedStringResource {
        isAlarm
            ? "Alarm — time sensitive, can be snoozed"
            : "Reminder"
    }

    /// Colour for a task saved before the palette existed, derived from its stored `TaskType`.
    static func legacyDefault(forTypeRaw typeRaw: String) -> TaskColor {
        typeRaw == TaskType.golden.rawValue ? .gold : fallback
    }
}
