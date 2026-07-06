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
    var typeRaw: String
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
        type: TaskType = .regular,
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
        self.typeRaw = type.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed accessors

extension DailyTask {
    var type: TaskType {
        get { TaskType(rawValue: typeRaw) ?? .regular }
        set { typeRaw = newValue.rawValue }
    }

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
            DailyTask(title: "Morning workout", startDate: at(7), durationMinutes: 60, type: .regular),
            DailyTask(
                title: "Team standup",
                details: "Daily sync with the iOS guild.",
                startDate: at(9, 30),
                durationMinutes: 30,
                type: .regular
            ),
            DailyTask(
                title: "Deep work block",
                details: "Focus on the timeline view layout.",
                startDate: at(10, 15),
                durationMinutes: 120,
                type: .golden
            ),
            DailyTask(title: "Lunch with Ana", startDate: at(13), durationMinutes: 60, type: .regular),
            DailyTask(title: "Evening read", startDate: at(21), durationMinutes: 30, type: .golden),
        ]
    }
}
#endif
