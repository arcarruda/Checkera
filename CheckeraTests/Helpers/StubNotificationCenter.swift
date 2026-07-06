import Foundation
import UserNotifications
@testable import Checkera

@MainActor
final class StubNotificationCenter: NotificationCenterAdapter {

    struct ScheduledRequest: Equatable {
        let identifier: String
        let title: String
        let body: String
        let soundName: String?
        let categoryIdentifier: String?
        let interruptionLevel: UNNotificationInterruptionLevel
        let components: DateComponents
    }

    var authorizationStatusValue: UNAuthorizationStatus = .notDetermined
    var authorizationGranted: Bool = true
    var scheduledRequests: [ScheduledRequest] = []
    var canceledIdentifiers: [String] = []
    var shouldThrowOnAuth = false
    var shouldThrowOnSchedule = false

    enum StubError: Error { case fail }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAuthorization() async throws -> Bool {
        if shouldThrowOnAuth { throw StubError.fail }
        authorizationStatusValue = authorizationGranted ? .authorized : .denied
        return authorizationGranted
    }

    func schedule(
        identifier: String,
        title: String,
        body: String,
        soundName: String?,
        categoryIdentifier: String?,
        interruptionLevel: UNNotificationInterruptionLevel,
        components: DateComponents
    ) async throws {
        if shouldThrowOnSchedule { throw StubError.fail }
        scheduledRequests.append(ScheduledRequest(
            identifier: identifier,
            title: title,
            body: body,
            soundName: soundName,
            categoryIdentifier: categoryIdentifier,
            interruptionLevel: interruptionLevel,
            components: components
        ))
    }

    func cancelRequests(identifiers: [String]) async {
        canceledIdentifiers.append(contentsOf: identifiers)
        scheduledRequests.removeAll { identifiers.contains($0.identifier) }
    }
}
