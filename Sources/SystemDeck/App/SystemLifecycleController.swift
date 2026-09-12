import AppKit
import Combine

// Resets sampling around system sleep and wake.
@MainActor
final class SystemLifecycleController: NSObject, ObservableObject {
    private weak var store: SystemMonitorStore?
    private let notificationCenter = NSWorkspace.shared.notificationCenter

    init(store: SystemMonitorStore) {
        self.store = store
        super.init()

        notificationCenter.addObserver(
            self,
            selector: #selector(handleWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc
    private func handleWillSleep(_ notification: Notification) {
        store?.prepareForSystemSleep()
    }
    @objc
    private func handleDidWake(_ notification: Notification) {
        store?.resumeAfterSystemWake()
    }
}
