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

    @Test("default type is regular")
    func defaultTypeIsRegular() {
        let task = DailyTask(title: "x", startDate: .now)
        #expect(task.type == .regular)
    }

    @Test("default endTimeWasManuallyEdited is false")
    func defaultManualEditFlagIsFalse() {
        let task = DailyTask(title: "x", startDate: .now)
        #expect(task.endTimeWasManuallyEdited == false)
    }

    // MARK: - Enum round-trip

    @Test("type round-trips via rawValue", arguments: TaskType.allCases)
    func typeRoundTrip(_ value: TaskType) {
        let task = DailyTask(title: "x", startDate: .now, type: value)
        #expect(task.type == value)
        #expect(TaskType(rawValue: task.typeRaw) == value)
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

    @Test("setting type updates raw value")
    func setTypeUpdatesRaw() {
        let task = DailyTask(title: "x", startDate: .now)
        task.type = .golden
        #expect(task.typeRaw == TaskType.golden.rawValue)
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
