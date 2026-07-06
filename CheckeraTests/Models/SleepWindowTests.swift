import Foundation
import Testing
@testable import Checkera

@Suite("SleepWindow")
struct SleepWindowTests {

    // MARK: - Defaults

    @Test("default is 6:00 AM wake, 11:00 PM bed")
    func defaults() {
        #expect(SleepWindow.default.wakeUpMinute == 360)
        #expect(SleepWindow.default.bedTimeMinute == 1380)
    }

    // MARK: - segments — bed > wake (normal)

    @Test("default produces leading and trailing segments")
    func defaultSegments() {
        let segments = SleepWindow.default.segments
        #expect(segments == [
            SleepWindow.Segment(startMinute: 0, endMinute: 360),
            SleepWindow.Segment(startMinute: 1380, endMinute: 1440)
        ])
    }

    @Test("wake at midnight drops the leading segment")
    func wakeAtMidnight() {
        let window = SleepWindow(wakeUpMinute: 0, bedTimeMinute: 1380)
        #expect(window.segments == [
            SleepWindow.Segment(startMinute: 1380, endMinute: 1440)
        ])
    }

    @Test("bed at end of day drops the trailing segment")
    func bedAtEndOfDay() {
        let window = SleepWindow(wakeUpMinute: 360, bedTimeMinute: 1439)
        #expect(window.segments == [
            SleepWindow.Segment(startMinute: 0, endMinute: 360),
            SleepWindow.Segment(startMinute: 1439, endMinute: 1440)
        ])
    }

    // MARK: - segments — wake > bed (inverted / night-shift)

    @Test("inverted window produces a single segment")
    func invertedSegments() {
        let window = SleepWindow(wakeUpMinute: 840, bedTimeMinute: 360)
        #expect(window.segments == [
            SleepWindow.Segment(startMinute: 360, endMinute: 840)
        ])
    }

    // MARK: - segments — equal

    @Test("equal wake and bed produces no segments")
    func equalProducesNoSegments() {
        let window = SleepWindow(wakeUpMinute: 360, bedTimeMinute: 360)
        #expect(window.segments.isEmpty)
    }

    // MARK: - Segment

    @Test("segment duration is end minus start")
    func segmentDuration() {
        let segment = SleepWindow.Segment(startMinute: 1380, endMinute: 1440)
        #expect(segment.durationMinutes == 60)
    }

    // MARK: - Clamping

    @Test("init clamps out-of-range values to [0, 1439]")
    func clampsOutOfRange() {
        let window = SleepWindow(wakeUpMinute: -30, bedTimeMinute: 5000)
        #expect(window.wakeUpMinute == 0)
        #expect(window.bedTimeMinute == 1439)
    }
}
