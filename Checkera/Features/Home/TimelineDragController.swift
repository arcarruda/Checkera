import os
import SwiftUI
import UIKit

/// Drives drag-to-reschedule with a single `UILongPressGestureRecognizer` installed on the
/// timeline's backing `UIScrollView` — not on the task rows.
///
/// Three per-row attempts at this gesture each died to a different touch-cancellation mechanism
/// (`.scrollDisabled` rebuilding the representable, recognizer-arbitration races, and
/// `canCancelContentTouches`). They shared one structural weakness: the recognizer lived on a
/// small overlay *inside* the scrolling content, where `UIScrollView` is entitled to cancel
/// subview touches and where any SwiftUI re-render of the row can restructure the hosting UIViews
/// under the live recognizer. A recognizer attached to the scroll view itself is subject to
/// neither — the scroll view's own pan is proof that recognizers at that level survive scrolling
/// arbitration — and rows can re-render freely mid-drag. This is the same shape as
/// `UICollectionView` reorder: the recognizer belongs to the container, not the cell.
///
/// The SwiftUI view is an invisible, non-interactive anchor filling the timeline canvas. It gives
/// the coordinator two things: a `didMoveToWindow` hook to install/remove the recognizer, and a
/// stable coordinate space — the anchor scrolls with the content, so a point converted into it is
/// a point on the 24-hour canvas (minute = y / pointsPerMinute), immune to content margins,
/// safe-area insets, and auto-scroll.
struct TimelineDragController: UIViewRepresentable {

    static let pressDuration: TimeInterval = 0.4
    /// Distance from the scroll view's visible top/bottom edge that arms auto-scroll.
    static let autoScrollBand: CGFloat = 90
    /// Peak auto-scroll speed in points per second, at full band deflection.
    static let autoScrollMaxSpeed: CGFloat = 320

    let isEnabled: Bool
    /// Resolves a point on the timeline canvas to the task rendered there, using the same
    /// geometry the rows are drawn with (`HomeModel.frame(for:availableWidth:)`).
    let taskAt: (CGPoint) -> DailyTask?
    let onBegan: (DailyTask) -> Void
    /// Vertical delta since pickup, in canvas points. Raw and continuous — snapping is the
    /// caller's business.
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void
    let onCancelled: () -> Void

    func makeUIView(context: Context) -> UIView {
        let anchor = AnchorView()
        anchor.backgroundColor = .clear
        // The anchor must never participate in touch handling — the recognizer lives on the
        // scroll view. This keeps the hour rows' tap-to-create fully reachable beneath it.
        anchor.isUserInteractionEnabled = false
        anchor.onWindowChange = { [weak coordinator = context.coordinator] view in
            coordinator?.anchorWindowChanged(view)
        }
        return anchor
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isEnabled = isEnabled
        coordinator.taskAt = taskAt
        coordinator.onBegan = onBegan
        coordinator.onChanged = onChanged
        coordinator.onEnded = onEnded
        coordinator.onCancelled = onCancelled
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class AnchorView: UIView {
        var onWindowChange: ((AnchorView) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(self)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var isEnabled: Bool
        var taskAt: (CGPoint) -> DailyTask?
        var onBegan: (DailyTask) -> Void
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat) -> Void
        var onCancelled: () -> Void

        private weak var anchor: AnchorView?
        private weak var scrollView: UIScrollView?
        private weak var recognizer: UILongPressGestureRecognizer?
        private var isDragging = false
        private var displayLink: CADisplayLink?
        private var autoScrollSpeed: CGFloat = 0
        private var beganCanvasY: CGFloat = 0
        private let logger = Logger(subsystem: "app.checkera", category: "Drag")

        init(_ view: TimelineDragController) {
            isEnabled = view.isEnabled
            taskAt = view.taskAt
            onBegan = view.onBegan
            onChanged = view.onChanged
            onEnded = view.onEnded
            onCancelled = view.onCancelled
        }

        // MARK: - Install / uninstall

        /// The pager's `TabView` detaches and reattaches pages; install on attach, tear down on
        /// detach so a recycled page never leaves a recognizer behind on the scroll view.
        func anchorWindowChanged(_ view: AnchorView) {
            if view.window == nil {
                uninstall()
            } else {
                anchor = view
                installIfNeeded(from: view)
            }
        }

        private func installIfNeeded(from view: UIView) {
            guard recognizer == nil else { return }
            // Nearest UIScrollView ancestor. From inside the timeline content that is always the
            // timeline's own scroll view — the horizontal day pager sits further up the chain
            // (verified against the captured hierarchy: anchor > … > HostingScrollView > … >
            // PagingCollectionView).
            var node = view.superview
            while let current = node, !(current is UIScrollView) {
                node = current.superview
            }
            guard let scroll = node as? UIScrollView else {
                logger.debug("install failed: no UIScrollView ancestor")
                return
            }

            let press = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleLongPress(_:))
            )
            press.minimumPressDuration = TimelineDragController.pressDuration
            press.delegate = self
            scroll.addGestureRecognizer(press)

            scrollView = scroll
            recognizer = press
            logger.debug("drag recognizer installed on scroll view")
        }

        func uninstall() {
            if let recognizer, let scrollView {
                scrollView.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            stopDisplayLink()
            autoScrollSpeed = 0
            scrollView = nil
            guard isDragging else { return }
            isDragging = false
            // The gesture's own `.cancelled` never arrives after removal; without notifying, the
            // lifted row would be stranded. Async because this can run during SwiftUI teardown.
            let notify = onCancelled
            DispatchQueue.main.async { notify() }
        }

        // MARK: - Delegate

        /// Only lift when the press actually lands on a task row. Anywhere else the long press
        /// declines, so holding on an empty slot never blocks that touch from scrolling.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let anchor else { return false }
            let point = gestureRecognizer.location(in: anchor)
            return taskAt(point) != nil
        }

        // MARK: - Long press → lift and drag

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                guard isEnabled, let anchor else { return }
                let point = gesture.location(in: anchor)
                guard let task = taskAt(point) else { return }
                beganCanvasY = gesture.location(in: scrollView).y
                isDragging = true
                logger.debug("drag began on task at canvas y \(point.y, privacy: .public)")
                onBegan(task)

            case .changed:
                guard isDragging else { return }
                updateAutoScroll()
                onChanged(currentDelta())

            case .ended:
                guard isDragging else { return }
                let delta = currentDelta()
                logger.debug(
                    "drag ended: canvasDelta=\(delta, privacy: .public)pt"
                )
                endDragSession()
                onEnded(delta)

            case .cancelled, .failed:
                guard isDragging else { return }
                // If this fires mid-drag, something stole the touch from a recognizer that lives
                // on the scroll view itself — worth knowing exactly when.
                logger.debug("drag cancelled by the system before the finger lifted")
                endDragSession()
                onCancelled()

            default:
                break
            }
        }

        // MARK: - Coordinates

        /// Vertical travel since pickup in the scroll view's content coordinate space. UIKit and
        /// SwiftUI both grow Y downward here, so dragging down produces the positive offset that
        /// `DayTimelineView` applies to the card. Because a scroll view's bounds origin is its
        /// content offset, querying the recognizer again during auto-scroll also includes the
        /// canvas travel beneath a stationary finger.
        private func currentDelta() -> CGFloat {
            guard let recognizer, let scrollView else { return 0 }
            return Self.canvasDelta(currentY: recognizer.location(in: scrollView).y, beganY: beganCanvasY)
        }

        static func canvasDelta(currentY: CGFloat, beganY: CGFloat) -> CGFloat {
            currentY - beganY
        }

        // MARK: - Auto-scroll

        private func updateAutoScroll() {
            guard let scrollView else {
                autoScrollSpeed = 0
                stopDisplayLink()
                return
            }
            // Both values use the scroll view's bounds coordinate space. Its visible top is
            // `bounds.minY` (the content offset), so their difference remains the finger's stable
            // on-screen position even while auto-scroll changes that offset.
            let viewportY = recognizer?.location(in: scrollView).y ?? 0
            let visibleTop = scrollView.bounds.minY
            let height = scrollView.bounds.height
            // Bands measure from the raw bounds edges: the bottom content margin is still
            // visible, touchable screen, so insetting the band would move the trigger zone up.
            // Scaled to the viewport so a phone-sized timeline does not spend a quarter of its
            // height auto-scrolling — a fixed 90pt band is a fifth of an iPhone timeline.
            let band = min(TimelineDragController.autoScrollBand, height * 0.12)
            let maxSpeed = TimelineDragController.autoScrollMaxSpeed

            if viewportY < visibleTop + band {
                let t = min(1, max(0, (visibleTop + band - viewportY) / band))
                autoScrollSpeed = -maxSpeed * t * t
            } else if viewportY > visibleTop + height - band {
                let t = min(1, max(0, (viewportY - (visibleTop + height - band)) / band))
                autoScrollSpeed = maxSpeed * t * t
            } else {
                autoScrollSpeed = 0
            }

            if autoScrollSpeed == 0 {
                stopDisplayLink()
            } else {
                startDisplayLink()
            }
        }

        private func startDisplayLink() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(stepAutoScroll(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func stepAutoScroll(_ link: CADisplayLink) {
            guard isDragging, let scrollView, autoScrollSpeed != 0 else { return }
            let dt = CGFloat(max(0, link.targetTimestamp - link.timestamp))
            let minY = -scrollView.adjustedContentInset.top
            let maxY = max(
                minY,
                scrollView.contentSize.height
                    + scrollView.adjustedContentInset.bottom
                    - scrollView.bounds.height
            )
            let target = min(max(scrollView.contentOffset.y + autoScrollSpeed * dt, minY), maxY)
            guard target != scrollView.contentOffset.y else { return }
            scrollView.contentOffset.y = target
            // The finger hasn't moved, so no `.changed` will arrive. Re-querying the recognizer
            // in scroll-view coordinates picks up the changed bounds origin.
            onChanged(currentDelta())
        }

        private func endDragSession() {
            stopDisplayLink()
            autoScrollSpeed = 0
            isDragging = false
        }
    }
}
