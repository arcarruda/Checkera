import Foundation

struct DayCopyService: Sendable {

    struct BringInPlan: Equatable, Sendable {
        let source: Date
        let target: Day
    }

    func plan(
        for target: Day,
        targetIsEmpty: Bool,
        latestPastNonEmptyDay: Date?
    ) -> BringInPlan? {
        guard target != .yesterday else { return nil }
        guard targetIsEmpty else { return nil }
        guard let source = latestPastNonEmptyDay else { return nil }
        return BringInPlan(source: source, target: target)
    }
}
