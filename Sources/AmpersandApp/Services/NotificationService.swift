import AmpersandCore
import Foundation
import UserNotifications

/// Posts a notification for unexpected exits (restart off) and for give-ups.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let enabledKey = "notificationsEnabled"

    var onOpenLog: ((UUID) -> Void)?
    private var askedForAuthorization = false

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Asked in context: the first time a command starts, never at launch.
    func requestAuthorizationIfNeeded() async {
        guard enabled, !askedForAuthorization else { return }
        askedForAuthorization = true
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func notifyIfNeeded(command spec: CommandSpec, from old: CommandStatus, to new: CommandStatus) {
        guard enabled, old != new else { return }
        let body: String
        switch new {
        case .exited(let exit, _):
            body = "\(spec.name) stopped unexpectedly (\(StatusText.exitLabel(exit)))."
        case .gaveUp(let exit, _):
            body = "\(spec.name) kept crashing (\(StatusText.exitLabel(exit))), so Ampersand stopped restarting it."
        default:
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Ampersand"
        content.body = body
        content.userInfo = ["commandID": spec.id.uuidString]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["commandID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run { self.onOpenLog?(id) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
