import SwiftUI

struct BringInTasksButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label {
                Text("Bring tasks from the last time")
            } icon: {
                Image(systemName: "square.and.arrow.down")
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(Text("Bring tasks from the last time"))
        .accessibilityHint(Text("Copies tasks from your most recent day with tasks into this day"))
    }
}

#Preview("Idle") {
    BringInTasksButton(onTap: {})
        .padding()
}
