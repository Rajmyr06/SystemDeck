import AppKit
import SwiftUI

// Keeps the compact monitor at a fixed content size.
@MainActor
final class CompactWindowManager {
    static let shared = CompactWindowManager()

    static let contentSize = NSSize(width: 640, height: 278)

    private init() {}

    func configure(_ window: NSWindow) {
        window.contentMinSize = Self.contentSize
        window.contentMaxSize = Self.contentSize
        window.setContentSize(Self.contentSize)
        window.styleMask.remove(.resizable)
        window.isRestorable = false
        window.level = .normal
    }
}

struct CompactWindowBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> CompactWindowProbeView {
        let view = CompactWindowProbeView()
        view.onWindowAttached = { window in
            CompactWindowManager.shared.configure(window)
        }
        return view
    }

    func updateNSView(_ nsView: CompactWindowProbeView, context: Context) {
        if let window = nsView.window {
            CompactWindowManager.shared.configure(window)
        }
    }
}

@MainActor
final class CompactWindowProbeView: NSView {
    var onWindowAttached: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindowAttached?(window)
        }
    }
}
