import SwiftUI

struct GoldenBadge: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(TaskColor.gold.fill)
            .accessibilityLabel(Text(String(localized: "Alarm task", comment: "Accessibility label for the badge marking a gold task that alarms")))
    }
}

#Preview {
    GoldenBadge()
        .font(.title)
        .padding()
}
