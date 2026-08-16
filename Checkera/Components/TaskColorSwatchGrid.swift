import SwiftUI

/// The task colour picker: a grid of tappable swatches.
///
/// Selection is shown with a checkmark rather than a ring alone, and gold keeps its star when
/// unselected, so neither the current choice nor gold's alarm behaviour is carried by hue alone.
/// Each swatch names itself to VoiceOver; the enclosing section's footer explains what gold does.
struct TaskColorSwatchGrid: View {
    @Binding var selection: TaskColor

    // Adaptive so eight 44pt targets wrap to two rows on a 320pt-wide device. The maximum keeps
    // the swatches clustered instead of stretching across the full width of a wide sheet.
    private let columns = [GridItem(.adaptive(minimum: 44, maximum: 52), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(TaskColor.allCases) { color in
                swatch(color)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func swatch(_ color: TaskColor) -> some View {
        let isSelected = selection == color
        Button {
            selection = color
        } label: {
            ZStack {
                Circle()
                    .fill(color.fill)
                    .frame(width: 30, height: 30)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1)
                } else if color.isAlarm {
                    // Gold carries alarm behaviour, so it stays identifiable when unselected.
                    Image(systemName: "star.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(color.title))
        .accessibilityValue(Text(color.behaviorDescription))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection: TaskColor = .gold
    return Form {
        Section {
            TaskColorSwatchGrid(selection: $selection)
        } header: {
            Text(verbatim: "Colour")
        }
    }
}
