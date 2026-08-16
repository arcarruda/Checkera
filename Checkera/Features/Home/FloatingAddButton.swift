import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    static let diameter: CGFloat = 58
    static let margin: CGFloat = 20
    /// Bottom space a scroll view reserves so its last rows clear the button.
    static let scrollClearance: CGFloat = diameter + margin * 2

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .frame(width: Self.diameter, height: Self.diameter)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 3)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Add task", comment: "Accessibility label for the floating add-task button on the home screen")))
        .accessibilityHint(Text(String(localized: "Double-tap to create a new task", comment: "Accessibility hint for the add-task button")))
    }
}

#Preview("Light") {
    FloatingAddButton(action: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .environment(\.colorScheme, .light)
}

#Preview("Dark") {
    FloatingAddButton(action: {})
        .padding()
        .background(Color(.systemGroupedBackground))
        .environment(\.colorScheme, .dark)
}
