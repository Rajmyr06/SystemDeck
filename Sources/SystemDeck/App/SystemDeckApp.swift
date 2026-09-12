import SwiftUI
import AppKit

@main
@MainActor
struct SystemDeckApp: App {
    @StateObject private var store: SystemMonitorStore
    @StateObject private var lifecycle: SystemLifecycleController

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        let store = SystemMonitorStore()
        _store = StateObject(wrappedValue: store)
        _lifecycle = StateObject(wrappedValue: SystemLifecycleController(store: store))
    }

    var body: some Scene {
        WindowGroup("SystemDeck", id: "dashboard") {
            DashboardView(store: store)
                .frame(minWidth: 1_000, minHeight: 650)
                .background {
                    DashboardWindowBridge()
                        .frame(width: 0, height: 0)
                }
                .task {
                    store.start()
                }
        }
        .defaultSize(width: 1_360, height: 850)

        WindowGroup("SystemDeck Compact", id: "compact") {
            CompactView(store: store)
                .task {
                    store.start()
                }
        }
        .defaultSize(width: 640, height: 278)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Label(
                "CPU \(Int(store.cpuUsage.rounded()))%",
                systemImage: "waveform.path.ecg"
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
        .commands {
            CommandMenu("Display") {
                Button("Toggle Full Screen") {
                    DashboardWindowManager.shared.toggleFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.control, .command])

                Button("Fit Dashboard to Available Screen") {
                    DashboardWindowManager.shared.fitToAvailableScreen()
                }
                .keyboardShortcut("m", modifiers: [.control, .option])
            }
        }
    }
}
