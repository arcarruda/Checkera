import Foundation
import Testing
@testable import Checkera

@Suite("DayCopyService")
struct DayCopyServiceTests {

    private let service = DayCopyService()

    private func date(daysFromNow offset: Int) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now))!
    }

    // MARK: - Yesterday target

    @Test("yesterday target always returns nil")
    func yesterdayAlwaysNil() {
        let yesterday = date(daysFromNow: -1)
        #expect(service.plan(for: .yesterday, targetIsEmpty: true, latestPastNonEmptyDay: yesterday) == nil)
        #expect(service.plan(for: .yesterday, targetIsEmpty: false, latestPastNonEmptyDay: yesterday) == nil)
        #expect(service.plan(for: .yesterday, targetIsEmpty: true, latestPastNonEmptyDay: nil) == nil)
    }

    // MARK: - Non-empty target

    @Test("non-empty target returns nil", arguments: [Day.today, .tomorrow])
    func nonEmptyTargetNil(_ target: Day) {
        let plan = service.plan(for: target, targetIsEmpty: false, latestPastNonEmptyDay: date(daysFromNow: -1))
        #expect(plan == nil)
    }

    // MARK: - Missing source

    @Test("nil latestPastNonEmptyDay returns nil", arguments: [Day.today, .tomorrow])
    func missingSourceNil(_ target: Day) {
        let plan = service.plan(for: target, targetIsEmpty: true, latestPastNonEmptyDay: nil)
        #expect(plan == nil)
    }

    // MARK: - Happy path

    @Test("today empty + source set → plan with today as target")
    func todayEmptyWithSource() {
        let source = date(daysFromNow: -1)
        let plan = service.plan(for: .today, targetIsEmpty: true, latestPastNonEmptyDay: source)
        #expect(plan == DayCopyService.BringInPlan(source: source, target: .today))
    }

    @Test("tomorrow empty + source set → plan with tomorrow as target")
    func tomorrowEmptyWithSource() {
        let source = date(daysFromNow: 0)
        let plan = service.plan(for: .tomorrow, targetIsEmpty: true, latestPastNonEmptyDay: source)
        #expect(plan == DayCopyService.BringInPlan(source: source, target: .tomorrow))
    }

    @Test("source many days in the past still produces a plan", arguments: [-7, -30, -180])
    func farPastSourceStillReturnsPlan(_ daysBack: Int) {
        let source = date(daysFromNow: daysBack)
        let plan = service.plan(for: .today, targetIsEmpty: true, latestPastNonEmptyDay: source)
        #expect(plan?.source == source)
        #expect(plan?.target == .today)
    }
}
