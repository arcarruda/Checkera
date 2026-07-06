import SwiftUI

struct DayTimelineView: View {
    let day: Day
    let placedTasks: [PlacedTask]
    let model: HomeModel
    let onSelectTask: (DailyTask) -> Void
    let onSelectSlot: (Int, Int) -> Void
    let onDeleteTask: (DailyTask) -> Void

    @State private var openTaskID: UUID?
    @Environment(\.appTabBarHeight) private var tabBarHeight

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
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
                .contentMargins(.bottom, tabBarHeight, for: .scrollContent)
                .onAppear { scrollToInitialHour(scrollProxy) }
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
        let yOffset = model.yOffset(for: task.startDate)
        let height = max(40, CGFloat(task.durationMinutes) * (HomeModel.hourHeight / 60) - 4)

        let usableWidth = max(0, availableWidth - HomeModel.leadingGutter - 16)
        let columnWidth = usableWidth / CGFloat(max(placed.columnCount, 1))
        let xBase = HomeModel.leadingGutter + 8
        let xColumn = columnWidth * CGFloat(placed.column)
        let rowWidth = max(0, columnWidth - 4)

        Group {
            if day.allowsTaskCreation {
                SwipeableTaskRow(
                    taskID: task.id,
                    openTaskID: $openTaskID,
                    onDelete: { onDeleteTask(task) },
                    onTap: { onSelectTask(task) }
                ) {
                    TaskRowCompact(task: task)
                        .frame(width: rowWidth, height: height)
                }
                .frame(width: rowWidth, height: height)
            } else {
                Button {
                    onSelectTask(task)
                } label: {
                    TaskRowCompact(task: task)
                        .frame(width: rowWidth, height: height)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(String(localized: "Show task details", comment: "Accessibility hint on a compact task row that opens the task detail sheet")))
            }
        }
        .offset(x: xBase + xColumn, y: yOffset)
        .zIndex(openTaskID == task.id ? 2 : 1)
    }

    private func scrollToInitialHour(_ proxy: ScrollViewProxy) {
        guard day == .today else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        proxy.scrollTo(max(0, hour - 1), anchor: .top)
    }
}
