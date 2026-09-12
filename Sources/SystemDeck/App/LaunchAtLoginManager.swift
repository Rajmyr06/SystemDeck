import Foundation
import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var lastError: String?

    private init() {
        status = SMAppService.mainApp.status
    }

    var isPackagedApp: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    var isEnabled: Bool {
        status == .enabled
    }

    var statusLabel: String {
        guard isPackagedApp else { return "Available after installing SystemDeck.app" }

        switch status {
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires approval in System Settings"
        case .notRegistered:
            return "Disabled"
        case .notFound:
            return "Registration unavailable"
        @unknown default:
            return "Unknown"
        }
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil

        guard isPackagedApp else {
            lastError = "Launch at Login is available after SystemDeck is packaged as an app."
            refresh()
            return
        }

        do {
            if enabled {
                if status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }
}
