import SwiftUI
import UIKit

struct SwipeableTaskRow<Content: View>: View {

    // MARK: - Inputs

    let taskID: UUID
    @Binding var openTaskID: UUID?
    let onDelete: () -> Void
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content

    // MARK: - State

    @State private var dragTranslation: CGFloat = 0

    private static var revealedOffset: CGFloat { -88 }
    private static var snapThreshold: CGFloat { -50 }
    private static var rubberBandLimit: CGFloat { -110 }

    private var isOpen: Bool { openTaskID == taskID }

    private var visibleOffset: CGFloat {
        let base: CGFloat = isOpen ? Self.revealedOffset : 0
        let raw = base + dragTranslation
        return max(Self.rubberBandLimit, min(0, raw))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .trailing) {
            content()
                .contentShape(Rectangle())
                .offset(x: visibleOffset)
                .overlay(
                    HorizontalSwipeGesture(
                        onTap: rowTapped,
                        onDragChanged: handleDragChanged,
                        onDragEnded: handleDragEnded
                    )
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text(String(localized: "Show task details", comment: "Accessibility hint on a compact task row that opens the task detail sheet")))
                .accessibilityAction { rowTapped() }
                .accessibilityAction(named: Text(String(localized: "Delete", comment: "VoiceOver action name to delete a task from the timeline"))) {
                    onDelete()
                }
            deleteAction
                .allowsHitTesting(isOpen)
        }
        .clipped()
        .onChange(of: openTaskID) { _, newValue in
            guard newValue != taskID, dragTranslation != 0 else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                dragTranslation = 0
            }
        }
    }

    // MARK: - Subviews

    private var deleteAction: some View {
        Button(role: .destructive, action: onDelete) {
            Image(systemName: "trash.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 88)
                .frame(maxHeight: .infinity)
                .background(Color.red)
        }
        .buttonStyle(.plain)
        .opacity(visibleOffset < 0 ? 1 : 0)
        .accessibilityLabel(Text(String(localized: "Delete task", comment: "Accessibility label on the destructive delete button revealed by swiping a timeline task to the left")))
        .accessibilityHidden(!isOpen)
    }

    // MARK: - Actions

    private func handleDragChanged(_ x: CGFloat) {
        dragTranslation = x
    }

    private func handleDragEnded(_ x: CGFloat) {
        let total = (isOpen ? Self.revealedOffset : 0) + x
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if total < Self.snapThreshold {
                openTaskID = taskID
            } else if isOpen {
                openTaskID = nil
            }
            dragTranslation = 0
        }
    }

    private func rowTapped() {
        if isOpen {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                openTaskID = nil
                dragTranslation = 0
            }
        } else {
            onTap()
        }
    }
}

// MARK: - UIKit-backed gesture forwarder

/// SwiftUI's `DragGesture` cannot axis-lock at gesture-begin time; even with
/// `.simultaneousGesture(...)`, the parent `ScrollView` and the child gesture
/// race for the touch and the outcome is non-deterministic.
///
/// `UIPanGestureRecognizer` with `gestureRecognizerShouldBegin(_:)` rejects
/// vertical pans before they begin, releasing the touch to the ancestor
/// `ScrollView`'s pan recognizer. Tap is handled here too — the overlay UIView
/// would otherwise swallow it.
private struct HorizontalSwipeGesture: UIViewRepresentable {
    let onTap: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onDragChanged = onDragChanged
        context.coordinator.onDragEnded = onDragEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onDragChanged: onDragChanged, onDragEnded: onDragEnded)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        var onDragChanged: (CGFloat) -> Void
        var onDragEnded: (CGFloat) -> Void

        init(
            onTap: @escaping () -> Void,
            onDragChanged: @escaping (CGFloat) -> Void,
            onDragEnded: @escaping (CGFloat) -> Void
        ) {
            self.onTap = onTap
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            switch gesture.state {
            case .changed:
                onDragChanged(translation.x)
            case .ended, .cancelled:
                onDragEnded(translation.x)
            default:
                break
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onTap()
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

#Preview("Swipeable row — interactive") {
    @Previewable @State var openID: UUID? = nil
    let task = DailyTask(title: "Team standup", startDate: .now, durationMinutes: 30, type: .regular)
    let golden = DailyTask(title: "Deep work block", startDate: .now.addingTimeInterval(60 * 60), durationMinutes: 90, type: .golden)

    VStack(spacing: 12) {
        SwipeableTaskRow(
            taskID: task.id,
            openTaskID: $openID,
            onDelete: { },
            onTap: { }
        ) {
            TaskRowCompact(task: task)
                .frame(height: 60)
        }

        SwipeableTaskRow(
            taskID: golden.id,
            openTaskID: $openID,
            onDelete: { },
            onTap: { }
        ) {
            TaskRowCompact(task: golden)
                .frame(height: 80)
        }
    }
    .padding()
}
