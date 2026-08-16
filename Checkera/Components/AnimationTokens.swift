import SwiftUI

extension Animation {

    /// The house spring for direct-manipulation snap-backs and settles — swipe reveal, slide-to-
    /// delete, drag-to-reschedule drops.
    static let checkeraSnap: Animation = .spring(response: 0.3, dampingFraction: 0.85)

    /// Reduce-motion aware variant of ``checkeraSnap``. Springs overshoot, which is exactly what
    /// Reduce Motion asks us not to do, so fall back to a short linear settle.
    static func checkeraSnap(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .checkeraSnap
    }

    /// Step animation while a dragged task moves between snap positions. Deliberately shorter and
    /// non-springy: it fires on every 15-minute step, so overshoot would read as wobble.
    static func checkeraDragStep(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.08) : .snappy(duration: 0.12)
    }
}
