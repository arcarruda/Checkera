import SwiftUI

struct TaskDetailSheet: View {
    let task: DailyTask
    let canEdit: Bool
    let onEditTask: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if canEdit {
                    HStack {
                        Spacer(minLength: 0)
                        Button(String(localized: "Edit", comment: "Edit task button in detail sheet")) {
                            onEditTask()
                        }
                        .buttonStyle(.borderless)
                        .tint(.green)
                        .accessibilityLabel(Text(String(localized: "Edit task", comment: "Accessibility label for edit button in task detail sheet")))
                    }
                }
                header
                if task.details.isEmpty {
                    Text(String(localized: "No details", comment: "Placeholder shown on the task detail sheet when the task has no details"))
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                } else {
                    Text(task.details)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.title.weight(.semibold))
                    .strikethrough(task.status == .notAccomplished)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(timeRange)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                TaskColorPill(color: task.color)
            }
            Spacer(minLength: 0)
            if task.color.isAlarm {
                GoldenBadge()
                    .font(.title3)
            }
        }
    }

    private var timeRange: String {
        let start = task.startDate.formatted(.dateTime.hour().minute())
        let end = task.endDate.formatted(.dateTime.hour().minute())
        return "\(start) – \(end)"
    }
}

#Preview("Regular") {
    Color.clear.sheet(isPresented: .constant(true)) {
        TaskDetailSheet(
            task: DailyTask(
                title: "Team standup",
                details: "Daily sync with the iOS guild.",
                startDate: .now,
                durationMinutes: 30,
                color: .blue
            ),
            canEdit: true,
            onEditTask: {}
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Long details") {
    Color.clear.sheet(isPresented: .constant(true)) {
        TaskDetailSheet(
            task: DailyTask(
                title: "Architecture review",
                details: String(repeating: "Walk through the new persistence layer, focus on the migration story, and capture follow-ups for the next sprint. ", count: 12),
                startDate: .now,
                durationMinutes: 90,
                color: .blue
            ),
            canEdit: true,
            onEditTask: {}
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("Golden, accomplished") {
    Color.clear.sheet(isPresented: .constant(true)) {
        TaskDetailSheet(
            task: DailyTask(
                title: "Deep work block",
                details: "Focus on the timeline view layout.",
                startDate: .now,
                durationMinutes: 120,
                color: .gold,
                status: .accomplished
            ),
            canEdit: true,
            onEditTask: {}
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("No details") {
    Color.clear.sheet(isPresented: .constant(true)) {
        TaskDetailSheet(
            task: DailyTask(
                title: "Quick check-in",
                details: "",
                startDate: .now,
                durationMinutes: 15,
                color: .blue
            ),
            canEdit: true,
            onEditTask: {}
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview("No edit") {
    Color.clear.sheet(isPresented: .constant(true)) {
        TaskDetailSheet(
            task: DailyTask(
                title: "Yesterday's meeting",
                details: "Completed yesterday.",
                startDate: .now.addingTimeInterval(-60 * 60 * 24),
                durationMinutes: 60,
                color: .blue,
                status: .accomplished
            ),
            canEdit: false,
            onEditTask: {}
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
