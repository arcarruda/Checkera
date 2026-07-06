import Foundation
import Testing
@testable import Checkera

@Suite("Day")
struct DayTests {

    // MARK: - allowsTaskCreation

    @Test("yesterday does not allow task creation")
    func yesterdayDisallowsCreation() {
        #expect(Day.yesterday.allowsTaskCreation == false)
    }

    @Test("today allows task creation")
    func todayAllowsCreation() {
        #expect(Day.today.allowsTaskCreation == true)
    }

    @Test("tomorrow allows task creation")
    func tomorrowAllowsCreation() {
        #expect(Day.tomorrow.allowsTaskCreation == true)
    }
}
