import Foundation
import Testing
@testable import Checkera

@Suite("TaskSnapshot helpers")
struct TaskSnapshotTests {

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func snapshot(startOffsetMinutes: Int, duration: Int = 30) -> TaskSnapshot {
        TaskSnapshot(
            id: UUID(),
            title: "Test",
            startDate: referenceDate.addingTimeInterval(TimeInterval(startOffsetMinutes * 60)),
            durationMinutes: duration
        )
    }

    @Test("returns task that started within the alert window")
    func justStartedWithinWindow() {
        let task = snapshot(startOffsetMinutes: -2)
        #expect([task].justStarted(within: 5, of: referenceDate) == task)
    }

    @Test("returns nil when task started before the window")
    func justStartedBeforeWindow() {
        let task = snapshot(startOffsetMinutes: -10, duration: 60)
        #expect([task].justStarted(within: 5, of: referenceDate) == nil)
    }

    @Test("returns nil when task has not started yet")
    func justStartedNotYetStarted() {
        let task = snapshot(startOffsetMinutes: 1)
        #expect([task].justStarted(within: 5, of: referenceDate) == nil)
    }

    @Test("returns nil when task already ended")
    func justStartedAlreadyEnded() {
        let task = snapshot(startOffsetMinutes: -30, duration: 15)
        #expect([task].justStarted(within: 5, of: referenceDate) == nil)
    }

    @Test("boundary at exactly N minutes is exclusive")
    func justStartedAtExactBoundary() {
        let task = snapshot(startOffsetMinutes: -5)
        #expect([task].justStarted(within: 5, of: referenceDate) == nil)
    }

    @Test("just under the boundary still alerts")
    func justStartedJustUnderBoundary() {
        let task = TaskSnapshot(
            id: UUID(),
            title: "Test",
            startDate: referenceDate.addingTimeInterval(-299),
            durationMinutes: 30
        )
        #expect([task].justStarted(within: 5, of: referenceDate) == task)
    }

    @Test("returns first active task when multiple match")
    func justStartedReturnsFirstMatch() {
        let first = snapshot(startOffsetMinutes: -3)
        let second = snapshot(startOffsetMinutes: -1)
        #expect([first, second].justStarted(within: 5, of: referenceDate) == first)
    }
}
