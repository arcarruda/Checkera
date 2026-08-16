import SwiftUI

struct TaskRowCompact: View {
    let task: DailyTask
    /// Prospective start time shown while the row is being dragged to a new slot. `task.startDate`
    /// itself is only written on drop, so the label needs its own override to stay live.
    var displayStart: Date?

    private var start: Date { displayStart ?? task.startDate }
    private var end: Date { start.addingTimeInterval(TimeInterval(task.durationMinutes * 60)) }

    var body: some View {
        HStack(spacing: 8) {
            accentBar
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text("\(start.formatted(.dateTime.hour().minute())) – \(end.formatted(.dateTime.hour().minute()))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if task.color.isAlarm {
                GoldenBadge()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        // A very low-alpha wash over the material, so eight hues read at a glance without
        // the 4pt bar having to carry the distinction on its own.
        .background(task.color.rowWash, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(task.color.rowStroke, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accentBar: some View {
        Rectangle()
            .fill(task.color.fill)
            .frame(width: 4)
            .clipShape(Capsule())
    }

    /// Spelled out because `.combine` would otherwise drop the colour entirely — it is only
    /// ever drawn, never written, in this row.
    private var accessibilityLabel: Text {
        Text(task.title)
            + Text(verbatim: ", ")
            + Text("\(start.formatted(.dateTime.hour().minute())) – \(end.formatted(.dateTime.hour().minute()))")
            + Text(verbatim: ", ")
            + Text(task.color.title)
    }
}

#Preview("Palette") {
    VStack(spacing: 8) {
        ForEach(TaskColor.allCases) { color in
            TaskRowCompact(task: DailyTask(
                title: "Deep work block",
                startDate: .now,
                durationMinutes: 90,
                color: color
            ))
        }
    }
    .frame(width: 320)
    .padding()
}
