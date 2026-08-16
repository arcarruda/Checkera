import SwiftUI

// SwiftUI rendering for `TaskColor`. Kept out of `TaskColor.swift` so that file stays
// Foundation-only for the widget target, which compiles the model but draws no task colours.
extension TaskColor {

    /// Flat colour for swatches, dots and tints.
    var tint: Color { Color(assetName) }

    /// How the accent bar and badges are filled.
    ///
    /// Gold keeps the yellow→orange gradient it has always had — this is now the single
    /// definition of it, replacing the three copies that used to live in `GoldenBadge`,
    /// `TaskRowCompact` and `TaskEditorView`.
    var fill: AnyShapeStyle {
        isAlarm
            ? AnyShapeStyle(LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .top,
                endPoint: .bottom
            ))
            : AnyShapeStyle(tint)
    }

    /// Very low-alpha wash used behind a task row so the colour reads without shouting.
    var rowWash: Color { tint.opacity(0.09) }

    /// Stroke colour for a task row, replacing the flat `.quaternary` hairline.
    var rowStroke: Color { tint.opacity(0.35) }
}
