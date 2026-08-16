import SwiftUI

struct DayTimelineView: View {
    let day: Day
    let placedTasks: [PlacedTask]
    let model: HomeModel
    let onSelectTask: (DailyTask) -> Void
    let onSelectSlot: (Int, Int) -> Void
    let onDeleteTask: (DailyTask) -> Void

    @State private var openTaskID: UUID?
    @State private var dragTask: DailyTask?
    @State private var dragBaselineMinute = 0
    /// Raw, continuous offset in canvas points — the card tracks the finger 1:1. Snapping applies
    /// to the time label, the haptic ticks, and the drop, never to the card position mid-drag.
    /// Updating this at event rate re-evaluates `body`, but diffing means only the dragged row's
    /// offset actually changes per frame; the other rows compare equal.
    @State private var dragOffsetPoints: CGFloat = 0
    /// Snapped delta in minutes, driving the live label and the per-step haptic latch.
    @State private var dragSnappedDelta = 0
    @State private var snapTick = 0
    @State private var dropTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        TimelineDragController(
                            isEnabled: day.allowsTaskCreation,
                            taskAt: { point in
                                // Resolve in REVERSE paint order. Cards are emitted by
                                // `ForEach(placedTasks)` at equal zIndex, so the *last* match is
                                // the one actually on top — and `frame(for:)` floors card height
                                // at 40pt, so back-to-back short tasks genuinely overlap (two
                                // 15-minute tasks own 16pt slots but draw 40pt rects). Using
                                // `.first` here lifted the earlier, visually-covered card while
                                // tap and swipe-to-delete hit the later one.
                                let hits = placedTasks.filter {
                                    model.frame(for: $0, availableWidth: proxy.size.width).contains(point)
                                }
                                // A swiped-open row draws at zIndex 2, above every zIndex-1 row
                                // regardless of its position in the array.
                                return (hits.last { $0.task.id == openTaskID } ?? hits.last)?.task
                            },
                            onBegan: beginDrag,
                            onChanged: updateDrag,
                            onEnded: endDrag,
                            onCancelled: cancelDrag
                        )
                        sleepIndicators
                        backbone
                        ForEach(placedTasks) { placed in
                            taskView(for: placed, availableWidth: proxy.size.width)
                        }
                        if day == .today {
                            NowIndicator(
                                leadingGutter: HomeModel.leadingGutter,
                                yOffsetForDate: { model.yOffset(for: $0) }
                            )
                            .zIndex(10)
                        }
                    }
                    .frame(width: proxy.size.width, height: HomeModel.hourHeight * 24, alignment: .topLeading)
                }
                .contentMargins(.top, 8, for: .scrollContent)
                .contentMargins(.bottom, FloatingAddButton.scrollClearance, for: .scrollContent)
                .onAppear { scrollToInitialHour(scrollProxy) }
                .sensoryFeedback(.selection, trigger: snapTick)
                .sensoryFeedback(.success, trigger: dropTick)
                .sensoryFeedback(trigger: dragTask?.id) { _, new in
                    new == nil ? nil : .impact(weight: .medium)
                }
            }
        }
    }

    private static let sleepIndicatorColor = Color.green

    @ViewBuilder
    private var sleepIndicators: some View {
        let pixelsPerMinute = HomeModel.hourHeight / 60
        ForEach(model.sleepWindow.segments, id: \.self) { segment in
            let segmentHeight = pixelsPerMinute * CGFloat(segment.durationMinutes)
            let yStart = pixelsPerMinute * CGFloat(segment.startMinute)

            VerticalDashedLine()
                .stroke(Self.sleepIndicatorColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: 1, height: segmentHeight)
                .offset(x: HomeModel.leadingGutter, y: yStart)
                .accessibilityHidden(true)

            Text(String(localized: "Sleep time", comment: "Horizontal label drawn at the top of a green dashed line on the timeline marking the sleep window. Sits behind tasks so they cover it where they overlap."))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Self.sleepIndicatorColor)
                .fixedSize()
                .offset(x: HomeModel.leadingGutter + 6, y: yStart + 2)
                .accessibilityHidden(true)
        }
    }

    private struct VerticalDashedLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return path
        }
    }

    private var backbone: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                hourRow(for: hour)
                    .id(hour)
            }
        }
    }

    @ViewBuilder
    private func hourRow(for hour: Int) -> some View {
        let row = HourRow(hour: hour, leadingGutter: HomeModel.leadingGutter)
            .frame(height: HomeModel.hourHeight)
            .contentShape(Rectangle())

        if day.allowsTaskCreation {
            row
                .onTapGesture(coordinateSpace: .local) { location in
                    onSelectSlot(hour, Self.snappedMinute(fromY: location.y))
                }
                .accessibilityAction(named: Text(String(localized: "Create task at \(Self.hourLabel(hour))", comment: "VoiceOver action: create a new task starting at the given hour"))) {
                    onSelectSlot(hour, 0)
                }
        } else {
            row
        }
    }

    private static func snappedMinute(fromY y: CGFloat) -> Int {
        let segmentHeight = HomeModel.hourHeight / 4
        let segment = max(0, min(3, Int(y / segmentHeight)))
        return segment * 15
    }

    private static func hourLabel(_ hour: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }

    @ViewBuilder
    private func taskView(for placed: PlacedTask, availableWidth: CGFloat) -> some View {
        let task = placed.task
        let frame = model.frame(for: placed, availableWidth: availableWidth)

        let isDragging = dragTask?.id == task.id
        let displayStart: Date? = isDragging && dragSnappedDelta != 0
            ? Calendar.current.date(byAdding: .minute, value: dragSnappedDelta, to: task.startDate)
            : nil

        Group {
            if day.allowsTaskCreation {
                SwipeableTaskRow(
                    taskID: task.id,
                    openTaskID: $openTaskID,
                    onDelete: { onDeleteTask(task) },
                    onTap: { onSelectTask(task) },
                    onNudge: { nudge(task, byMinutes: $0) }
                ) {
                    TaskRowCompact(task: task, displayStart: displayStart)
                        .frame(width: frame.width, height: frame.height)
                }
                .frame(width: frame.width, height: frame.height)
            } else {
                Button {
                    onSelectTask(task)
                } label: {
                    TaskRowCompact(task: task)
                        .frame(width: frame.width, height: frame.height)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(String(localized: "Show task details", comment: "Accessibility hint on a compact task row that opens the task detail sheet")))
            }
        }
        // Lift styling sits outside `SwipeableTaskRow`, whose `.clipped()` would crop the shadow.
        .scaleEffect(isDragging ? 1.03 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.22 : 0), radius: 10, y: 4)
        // No implicit animation on the offset: the card must stick to the finger. Lift and drop
        // are animated explicitly in beginDrag/endDrag.
        .offset(x: frame.minX, y: frame.minY + (isDragging ? dragOffsetPoints : 0))
        .zIndex(isDragging ? 20 : (openTaskID == task.id ? 2 : 1))
    }

    // MARK: - Drag to reschedule

    private func beginDrag(_ task: DailyTask) {
        dragBaselineMinute = HomeModel.minuteOfDay(task.startDate)
        dragOffsetPoints = 0
        dragSnappedDelta = 0
        withAnimation(.checkeraDragStep(reduceMotion: reduceMotion)) {
            openTaskID = nil
            dragTask = task
        }
    }

    private func updateDrag(deltaPoints: CGFloat) {
        guard let task = dragTask else { return }
        dragOffsetPoints = HomeModel.clampedDragOffset(
            deltaPoints,
            baselineMinute: dragBaselineMinute,
            durationMinutes: task.durationMinutes
        )
        let target = HomeModel.dropMinute(
            baselineMinute: dragBaselineMinute,
            deltaPoints: dragOffsetPoints,
            durationMinutes: task.durationMinutes
        )
        let snapped = target - dragBaselineMinute
        if snapped != dragSnappedDelta {
            dragSnappedDelta = snapped
            snapTick += 1
        }
    }

    private func endDrag(deltaPoints: CGFloat) {
        guard let task = dragTask else { return }
        updateDrag(deltaPoints: deltaPoints)
        let target = dragBaselineMinute + dragSnappedDelta
        let moved = dragSnappedDelta != 0
        // `moveTask` is synchronous, so the write and the offset reset land in one transaction —
        // the card settles from under the finger straight into its snapped slot.
        withAnimation(.checkeraSnap(reduceMotion: reduceMotion)) {
            model.moveTask(task, toMinuteOfDay: target, on: day)
            dragTask = nil
            dragOffsetPoints = 0
            dragSnappedDelta = 0
        }
        // Dragging back to the original slot is a cancel, not a commit — no success haptic.
        if moved { dropTick += 1 }
    }

    private func cancelDrag() {
        withAnimation(.checkeraSnap(reduceMotion: reduceMotion)) {
            dragTask = nil
            dragOffsetPoints = 0
            dragSnappedDelta = 0
        }
    }

    private func nudge(_ task: DailyTask, byMinutes minutes: Int) {
        let target = HomeModel.dropMinute(
            baselineMinute: HomeModel.minuteOfDay(task.startDate),
            deltaPoints: CGFloat(minutes) * HomeModel.pointsPerMinute,
            durationMinutes: task.durationMinutes
        )
        withAnimation(.checkeraSnap(reduceMotion: reduceMotion)) {
            _ = model.moveTask(task, toMinuteOfDay: target, on: day)
        }
    }

    private func scrollToInitialHour(_ proxy: ScrollViewProxy) {
        guard day == .today else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        proxy.scrollTo(max(0, hour - 1), anchor: .top)
    }
}
