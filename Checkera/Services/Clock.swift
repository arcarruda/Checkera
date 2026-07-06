import Foundation

protocol Clock: Sendable {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

struct FixedClock: Clock {
    let date: Date
    init(_ date: Date) { self.date = date }
    var now: Date { date }
}
