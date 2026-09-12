import AppKit
import SwiftUI

// AppKit window controls used by the main dashboard.
@MainActor
final class DashboardWindowManager {
    static let shared = DashboardWindowManager()

    private weak var dashboardWindow: NSWindow?
    private var didFitInitialWindow = false

    private init() {}

    func configure(_ window: NSWindow) {
        dashboardWindow = window

        window.styleMask.formUnion([
            .titled,
            .closable,
            .miniaturizable,
            .resizable
        ])

        window.collectionBehavior.insert(.fullScreenPrimary)
        window.collectionBehavior.remove(.fullScreenAuxiliary)
        window.level = .normal
        window.hidesOnDeactivate = false

        window.minSize = NSSize(width: 1_000, height: 650)
        window.contentMinSize = NSSize(width: 1_000, height: 650)
        window.isRestorable = true

        window.setFrameAutosaveName("SystemDeckDashboardWindow")

        FullScreenButtonTarget.shared.window = window

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.isHidden = false
            zoomButton.isEnabled = true

            zoomButton.target = FullScreenButtonTarget.shared
            zoomButton.action = #selector(FullScreenButtonTarget.toggleFullScreen(_:))
        }

        // Start inside the usable desktop area.
        if !didFitInitialWindow,
           !window.styleMask.contains(.fullScreen),
           let screen = window.screen ?? NSScreen.main {
            didFitInitialWindow = true
            window.setFrame(screen.visibleFrame, display: true, animate: false)
        }
    }

    func toggleFullScreen() {
        guard let window = dashboardWindow else { return }
        FullScreenButtonTarget.shared.window = window
        FullScreenButtonTarget.shared.toggleFullScreen(nil)
    }

    func fitToAvailableScreen() {
        guard let window = dashboardWindow else { return }

        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                self?.applyVisibleFrame()
            }
            return
        }

        applyVisibleFrame()
    }

    private func applyVisibleFrame() {
        guard let window = dashboardWindow,
              let screen = window.screen ?? NSScreen.main else {
            return
        }

        window.setFrame(screen.visibleFrame, display: true, animate: true)
        window.makeKeyAndOrderFront(nil)
    }
}

// Objective-C target for the green window button.
@MainActor
final class FullScreenButtonTarget: NSObject {
    static let shared = FullScreenButtonTarget()

    weak var window: NSWindow?

    @objc func toggleFullScreen(_ sender: Any?) {
        guard let window else { return }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.toggleFullScreen(sender)
    }
}

struct DashboardWindowBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> DashboardWindowProbeView {
        let view = DashboardWindowProbeView()
        view.onWindowAttached = { window in
            DashboardWindowManager.shared.configure(window)
        }
        return view
    }

    func updateNSView(_ nsView: DashboardWindowProbeView, context: Context) {
        if let window = nsView.window {
            DashboardWindowManager.shared.configure(window)
        }
    }
}

@MainActor
final class DashboardWindowProbeView: NSView {
    var onWindowAttached: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindowAttached?(window)
        }
    }
}
