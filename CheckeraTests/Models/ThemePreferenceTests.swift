import Foundation
import SwiftUI
import Testing
@testable import Checkera

@Suite("ThemePreference")
struct ThemePreferenceTests {

    // MARK: - colorScheme

    @Test("system maps to nil colorScheme")
    func systemMapsToNil() {
        #expect(ThemePreference.system.colorScheme == nil)
    }

    @Test("light maps to .light colorScheme")
    func lightMapsToLight() {
        #expect(ThemePreference.light.colorScheme == .light)
    }

    @Test("dark maps to .dark colorScheme")
    func darkMapsToDark() {
        #expect(ThemePreference.dark.colorScheme == .dark)
    }
}
