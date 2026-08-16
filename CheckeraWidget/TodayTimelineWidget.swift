import WidgetKit
import SwiftUI
import SwiftData
import os

struct TodayTimelineWidget: Widget {

    let kind: String = "TodayTimelineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTimelineProvider()) { entry in
            TodayTimelineWidgetView(entry: entry)
                .widgetURL(URL(string: "checkera://today"))
        }
        .configurationDisplayName(Text(
            String(localized: "Today timeline", comment: "Display name shown in the widget gallery.")
        ))
        .description(Text(
            String(localized: "See where you are on today's plan.", comment: "Description shown in the widget gallery.")
        ))
        .supportedFamilies([.systemMedium, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

enum WidgetBackground {
    static let standard = LinearGradient(
        colors: [
            Color(red: 0.345, green: 0.424, blue: 0.471), // #586c78
            Color(red: 0.137, green: 0.239, blue: 0.302), // #233d4d
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let alert = LinearGradient(
        colors: [
            Color(red: 0.224, green: 0.710, blue: 0.290), // #39b54a
            Color(red: 0.000, green: 0.408, blue: 0.216), // #006837
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// The window during which a task triggers the widget's alert state, starting at its `startDate`.
let widgetAlertWindowMinutes = 5

// MARK: - Entry

struct TodayTimelineEntry: TimelineEntry, Hashable {
    let date: Date
    let tasks: [TaskSnapshot]
}

// MARK: - Provider

struct TodayTimelineProvider: TimelineProvider {

    private let logger = Logger(subsystem: "app.checkera", category: "Widget")

    func placeholder(in context: Context) -> TodayTimelineEntry {
        TodayTimelineEntry(date: Date(), tasks: PlaceholderTasks.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTimelineEntry) -> Void) {
        let now = Date()
        let tasks = context.isPreview ? PlaceholderTasks.samples : fetchTodayTasks(at: now)
        completion(TodayTimelineEntry(date: now, tasks: tasks))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTimelineEntry>) -> Void) {
        let now = Date()
        let tasks = fetchTodayTasks(at: now)
        let entries = makeEntries(from: now, tasks: tasks)

        let cal = Calendar.current
        let nextMidnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86_400)

        let timeline = Timeline(entries: entries, policy: .after(nextMidnight))
        completion(timeline)
    }

    // MARK: - Helpers

    private func fetchTodayTasks(at now: Date) -> [TaskSnapshot] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.startDate >= start && $0.startDate < end },
            sortBy: [SortDescriptor(\.startDate)]
        )

        // Deliberately the non-fatal container: the widget can be the first process to open the
        // store after an app update, and crashing here would leave an unrecoverable blank widget.
        guard let container = PersistenceController.sharedIfAvailable else {
            logger.error("widget store unavailable")
            return []
        }

        do {
            let context = ModelContext(container)
            let tasks = try context.fetch(descriptor)
            return tasks.map(TaskSnapshot.init)
        } catch {
            logger.error("widget fetch failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    private func makeEntries(from now: Date, tasks: [TaskSnapshot]) -> [TodayTimelineEntry] {
        let cal = Calendar.current
        let endOfDay = cal.startOfDay(for: now).addingTimeInterval(86_400)

        var moments: Set<Date> = [now]

        var tick = nextHalfHour(after: now, calendar: cal)
        while tick < endOfDay {
            moments.insert(tick)
            tick = tick.addingTimeInterval(1800)
        }

        for task in tasks {
            if task.startDate > now && task.startDate < endOfDay {
                moments.insert(task.startDate)
            }
            let alertEnd = task.startDate.addingTimeInterval(TimeInterval(widgetAlertWindowMinutes * 60))
            if alertEnd > now && alertEnd < endOfDay {
                moments.insert(alertEnd)
            }
            if task.endDate > now && task.endDate < endOfDay {
                moments.insert(task.endDate)
            }
        }

        return moments
            .sorted()
            .prefix(50)
            .map { TodayTimelineEntry(date: $0, tasks: tasks) }
    }

    private func nextHalfHour(after date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        var next = DateComponents()
        next.year = comps.year
        next.month = comps.month
        next.day = comps.day
        if minute < 30 {
            next.hour = hour
            next.minute = 30
        } else {
            next.hour = hour + 1
            next.minute = 0
        }
        return calendar.date(from: next) ?? date.addingTimeInterval(1800)
    }
}

// MARK: - Placeholder samples

private enum PlaceholderTasks {
    static let samples: [TaskSnapshot] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return [
            TaskSnapshot(
                id: UUID(),
                title: "Stand-up",
                startDate: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today,
                durationMinutes: 15
            ),
            TaskSnapshot(
                id: UUID(),
                title: "Reading Time",
                startDate: cal.date(bySettingHour: 11, minute: 0, second: 0, of: today) ?? today,
                durationMinutes: 105
            ),
            TaskSnapshot(
                id: UUID(),
                title: "Lunch",
                startDate: cal.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today,
                durationMinutes: 60
            ),
        ]
    }()
}
