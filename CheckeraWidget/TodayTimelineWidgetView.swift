import SwiftUI
import WidgetKit

struct TodayTimelineWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: TodayTimelineEntry

    var body: some View {
        let alertTask = entry.tasks.justStarted(within: widgetAlertWindowMinutes, of: entry.date)
        let background = alertTask != nil ? WidgetBackground.alert : WidgetBackground.standard
        switch family {
        case .systemMedium:
            MediumLayout(entry: entry, isAlert: alertTask != nil)
                .containerBackground(background, for: .widget)
        case .accessoryRectangular:
            RectangularLayout(entry: entry, isAlert: alertTask != nil)
        case .accessoryInline:
            InlineLayout(entry: entry, isAlert: alertTask != nil)
        default:
            MediumLayout(entry: entry, isAlert: alertTask != nil)
                .containerBackground(background, for: .widget)
        }
    }
}

// MARK: - Medium

private struct MediumLayout: View {

    let entry: TodayTimelineEntry
    let isAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("BrandIconWhite")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 30)
                .accessibilityHidden(true)

            TimelineBar(tasks: entry.tasks, referenceDate: entry.date)
                .frame(height: 14)
                .padding(.vertical, 10)
                .overlay(alignment: .topTrailing) {
                    Text(String(
                        localized: "Today's timeline",
                        comment: "Label above the timeline bar in the medium widget, identifying the graphic."
                    ))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(y: -8)
                }

            CurrentTaskText(tasks: entry.tasks, referenceDate: entry.date)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .trailing) {
            if isAlert {
                Image("WidgetAlertBell")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                    .opacity(0.3)
                    .padding(.trailing, 8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityDescription(for: entry, isAlert: isAlert)))
    }
}

// MARK: - Accessory Rectangular

private struct RectangularLayout: View {

    let entry: TodayTimelineEntry
    let isAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CurrentTaskText(tasks: entry.tasks, referenceDate: entry.date, alertSymbol: isAlert)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            TimelineBar(tasks: entry.tasks, referenceDate: entry.date, drawDots: false)
                .frame(height: 6)
        }
        .containerBackground(.clear, for: .widget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityDescription(for: entry, isAlert: isAlert)))
    }
}

// MARK: - Accessory Inline

private struct InlineLayout: View {

    let entry: TodayTimelineEntry
    let isAlert: Bool

    var body: some View {
        let text = inlineText(for: entry)
        Group {
            if isAlert {
                Text("\(Image(systemName: "bell.fill")) \(text)")
            } else {
                Text(text)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Shared text

private struct CurrentTaskText: View {

    let tasks: [TaskSnapshot]
    let referenceDate: Date
    var alertSymbol: Bool = false

    var body: some View {
        let active = tasks.active(at: referenceDate)
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(active) { task in
                    label(for: activeLabel(for: task))
                }
            }
        } else if let upcoming = tasks.next(after: referenceDate) {
            label(for: nextLabel(for: upcoming))
        } else if let last = tasks.lastEnded(before: referenceDate) {
            label(for: lastLabel(for: last))
        } else {
            label(for: String(
                localized: "No tasks today",
                comment: "Widget label when there are no tasks scheduled for today."
            ))
        }
    }

    @ViewBuilder
    private func label(for text: String) -> some View {
        if alertSymbol {
            Text("\(Image(systemName: "bell.fill")) \(text)")
        } else {
            Text(text)
        }
    }

    private func activeLabel(for task: TaskSnapshot) -> String {
        let range = "\(formatHourMinute(task.startDate)) - \(formatHourMinute(task.endDate))"
        return String(
            localized: "Ongoing: \(range)  \(task.title)",
            comment: "Widget label for the currently active task. First placeholder is the start–end time range, second is the task title."
        )
    }

    private func nextLabel(for task: TaskSnapshot) -> String {
        let time = formatHourMinute(task.startDate)
        return String(
            localized: "Next: \(time)  \(task.title)",
            comment: "Widget label showing the next upcoming task. First placeholder is the start time, second is the task title."
        )
    }

    private func lastLabel(for task: TaskSnapshot) -> String {
        let range = "\(formatHourMinute(task.startDate)) - \(formatHourMinute(task.endDate))"
        return String(
            localized: "Last: \(range)  \(task.title)",
            comment: "Widget label shown when no task is active or upcoming, naming the most recently ended task. First placeholder is the start–end time range, second is the task title."
        )
    }
}

// MARK: - Helpers

private func formatHourMinute(_ date: Date) -> String {
    date.formatted(.dateTime.hour().minute())
}

private func inlineText(for entry: TodayTimelineEntry) -> String {
    if let active = entry.tasks.active(at: entry.date).first {
        return String(
            localized: "Ongoing: \(active.title)",
            comment: "Inline accessory widget label when a task is currently active. Placeholder is the task title."
        )
    }
    if let upcoming = entry.tasks.next(after: entry.date) {
        let time = formatHourMinute(upcoming.startDate)
        return String(
            localized: "Next: \(upcoming.title) at \(time)",
            comment: "Inline accessory widget label when no task is currently active. First placeholder is the task title, second is the start time."
        )
    }
    if let last = entry.tasks.lastEnded(before: entry.date) {
        return String(
            localized: "Last: \(last.title)",
            comment: "Inline accessory widget label when no task is active or upcoming, naming the most recently ended task. Placeholder is the task title."
        )
    }
    return String(
        localized: "No tasks today",
        comment: "Widget label when there are no tasks scheduled for today."
    )
}

private func accessibilityDescription(for entry: TodayTimelineEntry, isAlert: Bool = false) -> String {
    let active = entry.tasks.active(at: entry.date)
    if let first = active.first {
        if isAlert {
            return String(
                localized: "Today timeline. Starting now: \(first.title).",
                comment: "VoiceOver summary when a task has just started and the widget is in alert state."
            )
        }
        return String(
            localized: "Today timeline. Now: \(first.title).",
            comment: "VoiceOver summary when a task is currently active in the widget."
        )
    }
    if let upcoming = entry.tasks.next(after: entry.date) {
        let time = formatHourMinute(upcoming.startDate)
        return String(
            localized: "Today timeline. Next \(upcoming.title) at \(time).",
            comment: "VoiceOver summary when no task is active but one is coming up."
        )
    }
    if let last = entry.tasks.lastEnded(before: entry.date) {
        return String(
            localized: "Today timeline. Last \(last.title).",
            comment: "VoiceOver summary when no task is active or upcoming, naming the most recently ended task."
        )
    }
    return String(
        localized: "Today timeline. No tasks today.",
        comment: "VoiceOver summary when there are no tasks scheduled for today."
    )
}
