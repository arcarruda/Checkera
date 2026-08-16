import Foundation
import SwiftData

@Model
final class DailyTask {

    // MARK: - Stored

    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var startDate: Date
    var durationMinutes: Int
    var endTimeWasManuallyEdited: Bool
    /// Legacy regular/golden flag. Still written on every save so a downgrade to a build
    /// without the palette keeps golden tasks golden, and so tasks created before the
    /// palette can derive a colour. Never written directly — `color`'s setter owns it.
    var typeRaw: String
    /// Optional so the shipped store lightweight-migrates. `nil` means "saved before the
    /// palette existed" and is resolved from `typeRaw` — see `color`.
    var colorRaw: String?
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        startDate: Date,
        durationMinutes: Int = 30,
        endTimeWasManuallyEdited: Bool = false,
        color: TaskColor = .fallback,
        status: TaskStatus = .pending,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.endTimeWasManuallyEdited = endTimeWasManuallyEdited
        self.colorRaw = color.rawValue
        self.typeRaw = color.alarmType.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed accessors

extension DailyTask {
    /// The task's colour, and the only writable half of the colour/type pair.
    ///
    /// Tasks saved before the palette shipped have `colorRaw == nil` and fall back to a colour
    /// derived from `typeRaw`, so golden tasks stay gold and everything else becomes blue —
    /// no backfill needed. Setting it keeps `typeRaw` in step.
    var color: TaskColor {
        get {
            if let raw = colorRaw, let known = TaskColor(rawValue: raw) { return known }
            return TaskColor.legacyDefault(forTypeRaw: typeRaw)
        }
        set {
            colorRaw = newValue.rawValue
            typeRaw = newValue.alarmType.rawValue
        }
    }

    /// Derived from `color`, deliberately get-only: two writable properties over one concept
    /// would silently drift (a purple task that still fires the alarm category).
    var type: TaskType { color.alarmType }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
}

// MARK: - Sample data (for previews)

#if DEBUG
extension DailyTask {
    static var samples: [DailyTask] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func at(_ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }
        return [
            DailyTask(title: "Morning workout", startDate: at(7), durationMinutes: 60, color: .teal),
            DailyTask(
                title: "Team standup",
                details: "Daily sync with the iOS guild.",
                startDate: at(9, 30),
                durationMinutes: 30,
                color: .blue
            ),
            DailyTask(
                title: "Deep work block",
                details: "Focus on the timeline view layout.",
                startDate: at(10, 15),
                durationMinutes: 120,
                color: .gold
            ),
            DailyTask(title: "Lunch with Ana", startDate: at(13), durationMinutes: 60, color: .pink),
            DailyTask(title: "Evening read", startDate: at(21), durationMinutes: 30, color: .purple),
        ]
    }
}
#endif
