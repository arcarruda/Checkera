import Foundation

struct SleepWindow: Hashable, Sendable {

    static let minutesPerDay = 1440
    static let `default` = SleepWindow(wakeUpMinute: 360, bedTimeMinute: 1380)

    let wakeUpMinute: Int
    let bedTimeMinute: Int

    init(wakeUpMinute: Int, bedTimeMinute: Int) {
        self.wakeUpMinute = Self.clamp(wakeUpMinute)
        self.bedTimeMinute = Self.clamp(bedTimeMinute)
    }

    var segments: [Segment] {
        guard wakeUpMinute != bedTimeMinute else { return [] }
        if bedTimeMinute > wakeUpMinute {
            var result: [Segment] = []
            if wakeUpMinute > 0 {
                result.append(Segment(startMinute: 0, endMinute: wakeUpMinute))
            }
            if bedTimeMinute < Self.minutesPerDay {
                result.append(Segment(startMinute: bedTimeMinute, endMinute: Self.minutesPerDay))
            }
            return result
        } else {
            return [Segment(startMinute: bedTimeMinute, endMinute: wakeUpMinute)]
        }
    }

    private static func clamp(_ minute: Int) -> Int {
        max(0, min(Self.minutesPerDay - 1, minute))
    }
}

extension SleepWindow {

    struct Segment: Hashable, Sendable {
        let startMinute: Int
        let endMinute: Int

        var durationMinutes: Int { endMinute - startMinute }
    }
}
