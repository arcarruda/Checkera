import Foundation
import Testing
@testable import Checkera

@Suite("Clock")
struct ClockTests {

    // MARK: - FixedClock

    @Test("FixedClock returns supplied date")
    func fixedClockReturnsSuppliedDate() {
        let date = Date(timeIntervalSince1970: 1_234_567_890)
        let clock = FixedClock(date)
        #expect(clock.now == date)
    }

    @Test("FixedClock.now is constant across reads")
    func fixedClockIsConstant() {
        let clock = FixedClock(Date(timeIntervalSince1970: 0))
        #expect(clock.now == clock.now)
    }

    // MARK: - SystemClock

    @Test("SystemClock returns a current Date")
    func systemClockReturnsCurrentDate() {
        let before = Date()
        let now = SystemClock().now
        let after = Date()
        #expect(now >= before)
        #expect(now <= after)
    }
}
