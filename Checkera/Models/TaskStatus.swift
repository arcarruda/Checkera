import Foundation

enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case accomplished
    case notAccomplished
    case lateAccomplished
}
