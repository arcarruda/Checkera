import Foundation
import Testing
@testable import Checkera

@Suite("DailyTask")
struct DailyTaskTests {

    // MARK: - State invariants

    @Test("default status is pending")
    func defaultStatusIsPending() {
        let task = DailyTask(title: "x", startDate: .now)
        #expect(task.status == .pending)
    }

    @Test("default color is the fallback and implies a regular type")
    func defaultColorIsFallback() {
        let task = DailyTask(title: "x", startDate: .now)
        #expect(task.color == .fallback)
        #expect(task.type == .regular)
    }

    @Test("default endTimeWasManuallyEdited is false")
    func defaultManualEditFlagIsFalse() {
        let task = DailyTask(title: "x", startDate: .now)
        #expect(task.endTimeWasManuallyEdited == false)
    }

    // MARK: - Enum round-trip

    @Test("color round-trips via rawValue", arguments: TaskColor.allCases)
    func colorRoundTrip(_ value: TaskColor) {
        let task = DailyTask(title: "x", startDate: .now, color: value)
        #expect(task.color == value)
        #expect(TaskColor(rawValue: task.colorRaw ?? "") == value)
    }

    @Test("type is derived from color", arguments: TaskColor.allCases)
    func typeDerivedFromColor(_ value: TaskColor) {
        let task = DailyTask(title: "x", startDate: .now, color: value)
        #expect(task.type == (value == .gold ? .golden : .regular))
        #expect(task.typeRaw == task.type.rawValue)
    }

    // MARK: - Legacy tasks (saved before the palette shipped)

    @Test("a golden task with no stored color reads back as gold")
    func legacyGoldenDerivesGold() {
        let task = DailyTask(title: "x", startDate: .now)
        task.colorRaw = nil
        task.typeRaw = TaskType.golden.rawValue

        #expect(task.color == .gold)
        #expect(task.type == .golden)
    }

    @Test("a regular task with no stored color reads back as the fallback")
    func legacyRegularDerivesFallback() {
        let task = DailyTask(title: "x", startDate: .now)
        task.colorRaw = nil
        task.typeRaw = TaskType.regular.rawValue

        #expect(task.color == .fallback)
        #expect(task.type == .regular)
    }

    @Test("an unrecognised stored color falls back via the legacy type")
    func unknownColorFallsBack() {
        let task = DailyTask(title: "x", startDate: .now)
        task.colorRaw = "chartreuse"
        task.typeRaw = TaskType.golden.rawValue

        #expect(task.color == .gold)
    }

    @Test("status round-trips via rawValue", arguments: TaskStatus.allCases)
    func statusRoundTrip(_ value: TaskStatus) {
        let task = DailyTask(title: "x", startDate: .now, status: value)
        #expect(task.status == value)
        #expect(TaskStatus(rawValue: task.statusRaw) == value)
    }

    // MARK: - Computed accessors

    @Test("setting status updates raw value")
    func setStatusUpdatesRaw() {
        let task = DailyTask(title: "x", startDate: .now)
        task.status = .accomplished
        #expect(task.statusRaw == TaskStatus.accomplished.rawValue)
    }

    @Test("setting color updates both raw values")
    func setColorUpdatesRaws() {
        let task = DailyTask(title: "x", startDate: .now)

        task.color = .gold
        #expect(task.colorRaw == TaskColor.gold.rawValue)
        #expect(task.typeRaw == TaskType.golden.rawValue)

        task.color = .purple
        #expect(task.colorRaw == TaskColor.purple.rawValue)
        #expect(task.typeRaw == TaskType.regular.rawValue)
    }

    // MARK: - End-time derivation

    @Test("endDate equals startDate plus duration in minutes")
    func endDateDerivation() {
        let start = Date(timeIntervalSince1970: 0)
        let task = DailyTask(title: "x", startDate: start, durationMinutes: 90)
        #expect(task.endDate == start.addingTimeInterval(90 * 60))
    }

    @Test("endDate equals startDate when duration is zero")
    func endDateZeroDuration() {
        let start = Date(timeIntervalSince1970: 1_000)
        let task = DailyTask(title: "x", startDate: start, durationMinutes: 0)
        #expect(task.endDate == start)
    }
}
