import AppKit
import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationAuthorizationManager: ObservableObject {
    static let shared = NotificationAuthorizationManager()

    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    private init() {
        refresh()
    }

    var isPackagedApp: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    var statusLabel: String {
        guard isPackagedApp else { return "Available in SystemDeck.app" }

        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Allowed"
        case .denied:
            return "Blocked by macOS"
        case .notDetermined:
            return "Not requested"
        @unknown default:
            return "Unknown"
        }
    }

    var canDeliver: Bool {
        guard isPackagedApp else { return false }

        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func refresh() {
        // UserNotifications requires a real application bundle. `./run.sh` launches
        // the SwiftPM executable directly, so touching UNUserNotificationCenter
        // in that context raises an Objective-C exception before Swift can catch it.
        guard isPackagedApp else {
            status = .notDetermined
            lastError = nil
            return
        }

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self.status = settings.authorizationStatus
        }
    }

    func requestAuthorization() {
        guard isPackagedApp else {
            lastError = "Notifications are available after SystemDeck is packaged as an app."
            return
        }
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                lastError = granted ? nil : "Notifications were not allowed."
            } catch {
                lastError = error.localizedDescription
            }
            refresh()
        }
    }

    func post(identifier: String, title: String, body: String) {
        guard isPackagedApp, canDeliver else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
