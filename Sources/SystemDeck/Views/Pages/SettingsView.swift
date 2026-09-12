import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var store: SystemMonitorStore
    var embedded: Bool = false
    @AppStorage("glassIntensity") private var glassIntensity = 0.28
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared

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
                            Text("Fast telemetry follows the selected refresh interval. Process data refreshes at least every 5 seconds, while battery data refreshes every 30 seconds to keep background work low.")
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
        .onAppear { launchAtLogin.refresh() }
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
