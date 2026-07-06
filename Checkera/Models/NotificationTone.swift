import Foundation

enum NotificationTone: String, Codable, CaseIterable, Sendable {
    case regularDefault
    case regularChime
    case regularSubtle
    case goldenBell
    case goldenFanfare
    case goldenChime

    enum Category: Sendable {
        case regular
        case golden
    }

    var category: Category {
        switch self {
        case .regularDefault, .regularChime, .regularSubtle: .regular
        case .goldenBell, .goldenFanfare, .goldenChime: .golden
        }
    }
}
