import SwiftUI

/// A small filled circle in a task colour, used as a picker swatch and as a row icon.
struct TaskColorDot: View {
    let color: TaskColor
    var size: CGFloat = 16

    var body: some View {
        Circle()
            .fill(color.fill)
            .frame(width: size, height: size)
    }
}

/// The task's colour spelled out — dot plus name, and for gold the fact that it alarms.
///
/// Colour on its own is never the only carrier of this information; this pill is what makes
/// the palette legible to anyone who can't distinguish the hues.
struct TaskColorPill: View {
    let color: TaskColor

    var body: some View {
        HStack(spacing: 6) {
            TaskColorDot(color: color, size: 10)
            label
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: Text {
        guard color.isAlarm else { return Text(color.title) }
        return Text(color.title)
            + Text(verbatim: " · ")
            + Text(String(localized: "Alarm", comment: "Suffix on the gold colour pill, noting gold tasks alarm"))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(TaskColor.allCases) { color in
            HStack(spacing: 12) {
                TaskColorDot(color: color)
                TaskColorPill(color: color)
            }
        }
    }
    .padding()
}
