import SwiftUI

enum ThemePreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .system: "Inherit device theme"
        case .light:  "Light mode"
        case .dark:   "Dark mode"
        }
    }
}
