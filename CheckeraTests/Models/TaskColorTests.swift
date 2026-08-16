import Foundation
import SwiftUI
import UIKit
import Testing
@testable import Checkera

@Suite("TaskColor")
struct TaskColorTests {

    // MARK: - Persistence contract

    @Test("raw values are stable")
    func rawValuesAreStable() {
        // These strings are persisted in DailyTask.colorRaw, so they are user data —
        // renaming or dropping a case would orphan every task using it to the fallback colour.
        // Compared as a set on purpose: case *order* is a display decision (see paletteEndsWithGold),
        // and reordering the palette must not read as a persistence regression.
        #expect(Set(TaskColor.allCases.map(\.rawValue)) == [
            "gold", "blue", "teal", "green", "orange", "red", "purple", "pink",
        ])
    }

    @Test("the palette ends with gold")
    func paletteEndsWithGold() {
        // Gold is the only colour that changes behaviour, so it sits apart at the end of the
        // swatch grid and the Settings tone list. Both read TaskColor.allCases, i.e. declaration order.
        #expect(TaskColor.allCases.last == .gold)
    }

    @Test("the palette has eight colors")
    func paletteSize() {
        #expect(TaskColor.allCases.count == 8)
    }

    @Test("id matches rawValue", arguments: TaskColor.allCases)
    func idMatchesRawValue(_ color: TaskColor) {
        #expect(color.id == color.rawValue)
    }

    // MARK: - Alarm behaviour

    @Test("only gold alarms", arguments: TaskColor.allCases)
    func onlyGoldAlarms(_ color: TaskColor) {
        #expect(color.isAlarm == (color == .gold))
    }

    @Test("alarmType maps gold to golden and everything else to regular", arguments: TaskColor.allCases)
    func alarmTypeMapping(_ color: TaskColor) {
        #expect(color.alarmType == (color == .gold ? .golden : .regular))
    }

    @Test("each color's default tone is in its own category", arguments: TaskColor.allCases)
    func defaultToneCategoryMatches(_ color: TaskColor) {
        #expect((color.defaultTone.category == .golden) == color.isAlarm)
    }

    // MARK: - Legacy derivation

    @Test("legacyDefault maps the stored golden type to gold")
    func legacyGolden() {
        #expect(TaskColor.legacyDefault(forTypeRaw: TaskType.golden.rawValue) == .gold)
    }

    @Test("legacyDefault maps regular and anything unknown to the fallback", arguments: ["regular", "", "nonsense"])
    func legacyRegular(_ raw: String) {
        #expect(TaskColor.legacyDefault(forTypeRaw: raw) == .fallback)
    }

    @Test("the fallback color does not alarm")
    func fallbackIsQuiet() {
        #expect(TaskColor.fallback.isAlarm == false)
    }

    // MARK: - Assets

    @Test("every color resolves to a color set in the asset catalog", arguments: TaskColor.allCases)
    func assetResolves(_ color: TaskColor) {
        // Color(_:) fails silently to black on a typo, so check the catalog directly.
        #expect(UIColor(named: color.assetName, in: .main, compatibleWith: nil) != nil)
    }

    @Test("asset names are unique")
    func assetNamesAreUnique() {
        #expect(Set(TaskColor.allCases.map(\.assetName)).count == TaskColor.allCases.count)
    }
}
