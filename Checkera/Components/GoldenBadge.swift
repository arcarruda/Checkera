import SwiftUI

struct GoldenBadge: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .top,
                endPoint: .bottom
            ))
            .accessibilityLabel(Text(String(localized: "Golden task", comment: "Accessibility label for the golden task badge")))
    }
}

#Preview {
    GoldenBadge()
        .font(.title)
        .padding()
}
