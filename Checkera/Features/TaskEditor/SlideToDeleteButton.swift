import SwiftUI
import UIKit

struct SlideToDeleteButton: View {

    // MARK: - Inputs

    let onConfirm: () async -> Void

    // MARK: - State

    @State private var dragOffset: CGFloat = 0
    @State private var isCommitting = false
    @State private var didCrossThreshold = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants

    private static let trackHeight: CGFloat = 56
    private static let thumbSize: CGFloat = 48
    private static let horizontalInset: CGFloat = 4
    private static let commitThreshold: CGFloat = 0.85

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let maxDrag = max(0, geo.size.width - Self.thumbSize - 2 * Self.horizontalInset)
            let progress = maxDrag > 0 ? min(1, max(0, -dragOffset / maxDrag)) : 0

            track(progress: progress)
                .overlay { hint(progress: progress) }
                .overlay(alignment: .trailing) { thumb(maxDrag: maxDrag) }
        }
        .frame(height: Self.trackHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(String(
            localized: "Delete task",
            comment: "Accessibility label on the slide-to-confirm delete button"
        )))
        .accessibilityHint(Text(String(
            localized: "Activates the destructive delete action",
            comment: "Accessibility hint on the slide-to-delete control"
        )))
        .accessibilityAction(.default) { commit() }
    }

    // MARK: - Subviews

    private func track(progress: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Self.trackHeight / 2, style: .continuous)
            .fill(Color.red.opacity(0.12 + 0.55 * progress))
    }

    private func hint(progress: CGFloat) -> some View {
        let label: Text = Text(String(
            localized: "Slide to delete",
            comment: "Hint label inside the slide-to-confirm delete control"
        ))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.red)
        let opacity: Double = max(0.0, 1.0 - 1.4 * Double(progress))
        return label.opacity(opacity)
    }

    private func thumb(maxDrag: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color.red)
            if isCommitting {
                ProgressView().tint(.white)
            } else {
                Image(systemName: "trash.fill")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: Self.thumbSize, height: Self.thumbSize)
        .padding(.trailing, Self.horizontalInset)
        .offset(x: dragOffset)
        .contentShape(Circle())
        .gesture(dragGesture(maxDrag: maxDrag))
    }

    // MARK: - Gesture

    private func dragGesture(maxDrag: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isCommitting, maxDrag > 0 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                dragOffset = max(-maxDrag, min(0, value.translation.width))

                let progress = -dragOffset / maxDrag
                if progress >= Self.commitThreshold, !didCrossThreshold {
                    didCrossThreshold = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else if progress < Self.commitThreshold, didCrossThreshold {
                    didCrossThreshold = false
                }
            }
            .onEnded { _ in
                guard !isCommitting, maxDrag > 0 else { return }
                let progress = -dragOffset / maxDrag
                if progress >= Self.commitThreshold {
                    commit()
                } else {
                    snapBack()
                }
            }
    }

    // MARK: - Actions

    private func commit() {
        guard !isCommitting else { return }
        isCommitting = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            await onConfirm()
            await MainActor.run {
                snapBack()
                isCommitting = false
            }
        }
    }

    private func snapBack() {
        let animation: Animation = reduceMotion
            ? .linear(duration: 0.15)
            : .spring(response: 0.3, dampingFraction: 0.85)
        withAnimation(animation) {
            dragOffset = 0
        }
        didCrossThreshold = false
    }
}

#Preview {
    SlideToDeleteButtonPreview()
}

private struct SlideToDeleteButtonPreview: View {

    @State private var lastAction: String = "Idle"

    var body: some View {
        Form {
            Section {
                Text("Last action: \(lastAction)")
            }
            Section {
                SlideToDeleteButton {
                    lastAction = "Confirmed at \(Date().formatted(date: .omitted, time: .standard))"
                    try? await Task.sleep(for: .milliseconds(600))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
    }
}
