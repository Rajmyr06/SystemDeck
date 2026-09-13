import SwiftUI
import AppKit
import UserNotifications

@MainActor
struct SettingsView: View {
    @ObservedObject var store: SystemMonitorStore
    var embedded: Bool = false
    @AppStorage("glassIntensity") private var glassIntensity = 0.28

    @AppStorage("menuBarMetric.cpu") private var menuCPU = true
    @AppStorage("menuBarMetric.gpu") private var menuGPU = false
    @AppStorage("menuBarMetric.memory") private var menuMemory = false
    @AppStorage("menuBarMetric.network") private var menuNetwork = false
    @AppStorage("menuBarMetric.battery") private var menuBattery = false
    @AppStorage("menuBarMetric.thermal") private var menuThermal = false

    @AppStorage("thresholdAlerts.enabled") private var thresholdAlertsEnabled = false
    @AppStorage("thresholdAlert.cpu.enabled") private var cpuAlertEnabled = true
    @AppStorage("thresholdAlert.memory.enabled") private var memoryAlertEnabled = true
    @AppStorage("thresholdAlert.storage.enabled") private var storageAlertEnabled = true
    @AppStorage("thresholdAlert.thermal.enabled") private var thermalAlertEnabled = true
    @AppStorage("thresholdAlert.battery.enabled") private var batteryAlertEnabled = true

    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var notifications = NotificationAuthorizationManager.shared

    var body: some View {
        ZStack {
            if !embedded { DeckBackground() }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        title: "Settings",
                        subtitle: "Monitoring, appearance, diagnostics, and window controls"
                    )

                    settingsSection(title: "Monitoring", tint: DeckTheme.cyan) {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Refresh interval", selection: $store.refreshInterval) {
                                Text("1 second").tag(1.0)
                                Text("2 seconds").tag(2.0)
                                Text("5 seconds").tag(5.0)
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Text("Status")
                                    .foregroundStyle(DeckTheme.secondaryText)
                                Spacer()
                                MonitoringIndicator(active: store.isMonitoring)
                            }

                            Text("1 second gives the most responsive graphs. Longer intervals reduce update frequency and background work.")
                                .font(.system(size: 11))
                                .foregroundStyle(DeckTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                Button(store.isMonitoring ? "Pause monitoring" : "Resume monitoring") {
                                    store.isMonitoring ? store.stop() : store.start()
                                }
                                .buttonStyle(DeckFilledButtonStyle(tint: store.isMonitoring ? DeckTheme.statusElevated : DeckTheme.statusNormal))

                                Button("Refresh now") { store.refreshNow() }
                                    .buttonStyle(DeckFilledButtonStyle(tint: DeckTheme.accent))
                            }
                        }
                    }

                    settingsSection(title: "Liquid Glass", tint: DeckTheme.violet) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Color intensity")
                                    .foregroundStyle(DeckTheme.secondaryText)
                                Spacer()
                                Text(String(format: "%.0f%%", glassIntensity * 100))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(DeckTheme.primaryText)
                            }

                            Slider(value: $glassIntensity, in: 0.10...0.70, step: 0.01)
                                .tint(DeckTheme.violet)

                            Text("Adjusts the tint and depth of SystemDeck surfaces. Higher values make the glass treatment more visible.")
                                .font(.system(size: 11))
                                .foregroundStyle(DeckTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    settingsSection(title: "Window", tint: DeckTheme.accent) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Button("Toggle full screen") {
                                    DashboardWindowManager.shared.toggleFullScreen()
                                }
                                .buttonStyle(DeckFilledButtonStyle(tint: DeckTheme.accent))

                                Button("Fit to available screen") {
                                    DashboardWindowManager.shared.fitToAvailableScreen()
                                }
                                .buttonStyle(DeckFilledButtonStyle(tint: DeckTheme.indigo))
                            }

                            Text("Full Screen opens SystemDeck in native macOS full screen. Fit to Available Screen fills the usable desktop area without covering the Dock.")
                                .font(.system(size: 11))
                                .foregroundStyle(DeckTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }


                    settingsSection(title: "Application", tint: DeckTheme.indigo) {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(
                                "Launch at Login",
                                isOn: Binding(
                                    get: { launchAtLogin.isEnabled },
                                    set: { launchAtLogin.setEnabled($0) }
                                )
                            )
                            .toggleStyle(.switch)
                            .tint(DeckTheme.accent)
                            .disabled(!launchAtLogin.isPackagedApp)

                            HStack {
                                Text("Startup")
                                    .foregroundStyle(DeckTheme.secondaryText)
                                Spacer()
                                Text(launchAtLogin.statusLabel)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(launchAtLogin.isEnabled ? DeckTheme.statusNormal : DeckTheme.secondaryText)
                            }

                            if launchAtLogin.status == .requiresApproval {
                                Button("Open Login Items Settings") {
                                    launchAtLogin.openLoginItemsSettings()
                                }
                                .buttonStyle(DeckFilledButtonStyle(tint: DeckTheme.statusElevated))
                            }

                            if let error = launchAtLogin.lastError {
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundStyle(DeckTheme.statusElevated)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            DeckDivider()

                            HStack {
                                Text("Version")
                                    .foregroundStyle(DeckTheme.secondaryText)
                                Spacer()
                                Text("\(SystemDeckRelease.version) (\(SystemDeckRelease.build))")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(DeckTheme.primaryText)
                            }

                            HStack {
                                Text("Bundle")
                                    .foregroundStyle(DeckTheme.secondaryText)
                                Spacer()
                                Text(SystemDeckRelease.bundleIdentifier)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(DeckTheme.secondaryText)
                            }
                        }
                    }

                    settingsSection(title: "Menu Bar Live Strip", tint: DeckTheme.cyan) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Show up to three live values directly in the macOS menu bar. Click the strip to open SystemDeck's quick telemetry panel.")
                                .font(.system(size: 11))
                                .foregroundStyle(DeckTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                Text("Preview")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(DeckTheme.mutedText)
                                Text(menuBarPreview)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(DeckTheme.primaryText)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(DeckTheme.dataSurface.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            menuBarToggle("CPU", isOn: $menuCPU)
                            menuBarToggle("GPU", isOn: $menuGPU)
                            menuBarToggle("Memory", isOn: $menuMemory)
                            menuBarToggle("Network", isOn: $menuNetwork)
                            menuBarToggle("Battery", isOn: $menuBattery)
                            menuBarToggle("Thermal", isOn: $menuThermal)
                        }
                    }

                    settingsSection(title: "Notifications", tint: DeckTheme.statusElevated) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(
                                "Threshold alerts",
                                isOn: Binding(
                                    get: { thresholdAlertsEnabled },
                                    set: { enabled in
                                        thresholdAlertsEnabled = enabled
                                        if enabled { notifications.requestAuthorization() }
                                    }
                                )
                            )
                            .toggleStyle(.switch)
                            .tint(DeckTheme.statusElevated)
                            .disabled(!notifications.isPackagedApp)

                            HStack {
                                Text("Permission")
                                    .foregroundStyle(DeckTheme.secondaryText)
                                Spacer()
                                Text(notifications.statusLabel)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(notifications.canDeliver ? DeckTheme.statusNormal : DeckTheme.secondaryText)
                            }

                            if notifications.status == .denied {
                                Button("Open Notification Settings") {
                                    notifications.openNotificationSettings()
                                }
                                .buttonStyle(DeckFilledButtonStyle(tint: DeckTheme.statusElevated))
                            }

                            if let error = notifications.lastError {
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundStyle(DeckTheme.statusElevated)
                            }

                            DeckDivider()

                            alertToggle("CPU", detail: "> 90% for 30 seconds", isOn: $cpuAlertEnabled)
                            alertToggle("Memory", detail: "High or critical memory pressure", isOn: $memoryAlertEnabled)
                            alertToggle("Storage", detail: "> 90% used", isOn: $storageAlertEnabled)
                            alertToggle("Thermal", detail: "High or critical thermal pressure", isOn: $thermalAlertEnabled)
                            alertToggle("Battery", detail: "Below 20% while on battery", isOn: $batteryAlertEnabled)

                            Text("Alerts use a 10-minute cooldown and reset after the condition recovers.")
                                .font(.system(size: 10))
                                .foregroundStyle(DeckTheme.mutedText)
                        }
                    }

                    settingsSection(title: "Diagnostics", tint: DeckTheme.aqua) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Collector health, sample freshness, and the latest useful reading.")
                                .font(.system(size: 11))
                                .foregroundStyle(DeckTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Healthy = current data · Limited = partial data or a constrained system state · Stale = no recent sample · Unavailable = source not exposed · Failed = repeated collection failures")
                                .font(.system(size: 9.5))
                                .foregroundStyle(DeckTheme.mutedText)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(store.diagnostics) { item in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(diagnosticTint(item.state))
                                        .frame(width: 7, height: 7)

                                    Text(item.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(DeckTheme.primaryText)
                                        .frame(width: 110, alignment: .leading)

                                    Text(item.state.rawValue)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(diagnosticTint(item.state))
                                        .frame(width: 82, alignment: .leading)

                                    Text(item.detail)
                                        .font(.system(size: 10))
                                        .foregroundStyle(DeckTheme.secondaryText)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer(minLength: 0)
                                }
                            }

                            if let lastError = store.lastError {
                                DeckDivider()
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(DeckTheme.statusElevated)
                                    Text(lastError)
                                        .font(.system(size: 10))
                                        .foregroundStyle(DeckTheme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    settingsSection(title: "Energy & Safety", tint: DeckTheme.aqua) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fast telemetry follows the selected refresh interval. Process snapshots refresh at least every 5 seconds. Battery state and electrical telemetry refresh every 5 seconds, while slower system-pressure data refreshes every 30 seconds.")
                                .font(.system(size: 11))
                                .foregroundStyle(DeckTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("SystemDeck only reads system telemetry. It does not terminate apps, change system settings, or modify macOS behavior.")
                                .font(.system(size: 11))
                                .foregroundStyle(DeckTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(22)
            }
        }
        .frame(minWidth: embedded ? 0 : 590, minHeight: embedded ? 0 : 560)
        .onAppear {
            launchAtLogin.refresh()
            notifications.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            notifications.refresh()
        }
        .preferredColorScheme(.dark)
    }

    private func settingsSection<Content: View>(
        title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        DataSurface(tint: tint) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DeckTheme.primaryText)
                content()
            }
        }
    }

    private var selectedMenuBarMetricCount: Int {
        [menuCPU, menuGPU, menuMemory, menuNetwork, menuBattery, menuThermal]
            .filter { $0 }
            .count
    }

    private var menuBarPreview: String {
        var parts: [String] = []
        if menuCPU { parts.append("CPU \(DeckFormat.percent(store.cpuUsage))") }
        if menuGPU, store.gpu.available { parts.append("GPU \(DeckFormat.percent(store.gpu.utilizationPercent))") }
        if menuMemory { parts.append("RAM \(DeckFormat.percent(store.memory.usagePercent))") }
        if menuNetwork, store.network.available { parts.append("↓\(previewRate(store.network.downloadBytesPerSecond)) ↑\(previewRate(store.network.uploadBytesPerSecond))") }
        if menuBattery, store.battery.available { parts.append("BAT \(DeckFormat.percent(store.battery.percentage))") }
        if menuThermal, store.thermal.available { parts.append("THERM \(store.thermal.displayName)") }
        return parts.isEmpty ? "SystemDeck" : Array(parts.prefix(3)).joined(separator: " · ")
    }

    private func previewRate(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0" }
        if value >= 1_000_000_000 { return String(format: "%.1fG", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0fK", value / 1_000) }
        return String(format: "%.0fB", value)
    }

    @ViewBuilder
    private func menuBarToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.switch)
            .tint(DeckTheme.cyan)
            .disabled(!isOn.wrappedValue && selectedMenuBarMetricCount >= 3)
    }

    @ViewBuilder
    private func alertToggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DeckTheme.primaryText)
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(DeckTheme.mutedText)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(DeckTheme.statusElevated)
                .disabled(!thresholdAlertsEnabled)
        }
        .opacity(thresholdAlertsEnabled ? 1 : 0.58)
    }

    private func diagnosticTint(_ state: DiagnosticState) -> Color {
        switch state {
        case .healthy: DeckTheme.statusNormal
        case .limited: DeckTheme.statusElevated
        case .stale: DeckTheme.statusHigh
        case .unavailable: DeckTheme.statusUnavailable
        case .failed: DeckTheme.statusCritical
        }
    }

}

private struct DeckFilledButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        DeckFilledButtonBody(configuration: configuration, tint: tint)
    }
}

private struct DeckFilledButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let tint: Color
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DeckTheme.primaryText)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: DeckTheme.controlCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(fillTopOpacity),
                                tint.opacity(fillBottomOpacity),
                                DeckTheme.surface.opacity(0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: DeckTheme.controlCornerRadius, style: .continuous)
                    .stroke(tint.opacity(borderOpacity), lineWidth: 1)
            }
            .shadow(
                color: tint.opacity(shadowOpacity),
                radius: hovering && !configuration.isPressed ? 12 : 8,
                x: 0,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.985 : (hovering && !reduceMotion ? 1.01 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
            .onHover { hovering = $0 }
    }

    private var fillTopOpacity: Double {
        if configuration.isPressed { return 0.34 }
        return hovering ? 0.56 : 0.46
    }

    private var fillBottomOpacity: Double {
        if configuration.isPressed { return 0.20 }
        return hovering ? 0.36 : 0.30
    }

    private var borderOpacity: Double {
        if configuration.isPressed { return 0.56 }
        return hovering ? 0.95 : 0.80
    }

    private var shadowOpacity: Double {
        if configuration.isPressed { return 0.08 }
        return hovering ? 0.28 : 0.18
    }
}
