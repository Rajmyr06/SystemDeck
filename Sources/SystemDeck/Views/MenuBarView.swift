import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: SystemMonitorStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            DeckDivider()

            VStack(spacing: 0) {
                MenuMetricRow(label: "CPU", value: DeckFormat.percent(store.cpuUsage), history: store.cpuHistory, tint: DeckTheme.accent)
                MenuMetricRow(label: "GPU", value: store.gpu.available ? DeckFormat.percent(store.gpu.utilizationPercent) : "N/A", history: store.gpuHistory, tint: DeckTheme.cyan)
                MenuMetricRow(label: "Memory", value: DeckFormat.percent(store.memory.usagePercent), history: store.memoryHistory, tint: DeckTheme.violet)
            }
            .padding(.vertical, 4)

            DeckDivider()

            telemetryStrip
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            DeckDivider()

            VStack(spacing: 2) {
                MenuActionRow(symbol: "rectangle.grid.2x2", title: "Open Dashboard") {
                    openWindow(id: "dashboard")
                }
                MenuActionRow(symbol: "rectangle.compress.vertical", title: "Open Compact Monitor") {
                    openWindow(id: "compact")
                }
                MenuActionRow(
                    symbol: store.isMonitoring ? "pause.fill" : "play.fill",
                    title: store.isMonitoring ? "Pause Monitoring" : "Resume Monitoring"
                ) {
                    store.isMonitoring ? store.stop() : store.start()
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)

            DeckDivider()

            MenuActionRow(symbol: "power", title: "Quit SystemDeck", destructive: true) {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
        }
        .frame(width: 390)
        .background(.regularMaterial)
        .background(DeckTheme.backgroundLifted.opacity(0.68))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DeckTheme.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("SystemDeck")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DeckTheme.primaryText)
                Text(store.hardware.computerName)
                    .font(.system(size: 10))
                    .foregroundStyle(DeckTheme.secondaryText)
            }

            Spacer()
            MonitoringIndicator(active: store.isMonitoring)
        }
    }

    private var telemetryStrip: some View {
        HStack(spacing: 0) {
            MiniTelemetry(symbol: "arrow.down", label: "Download", value: DeckFormat.rate(store.network.downloadBytesPerSecond), tint: DeckTheme.aqua)
            Spacer(minLength: 8)
            MiniTelemetry(symbol: "arrow.up", label: "Upload", value: DeckFormat.rate(store.network.uploadBytesPerSecond), tint: DeckTheme.indigo)

            if store.battery.available {
                Spacer(minLength: 8)
                MiniTelemetry(
                    symbol: store.battery.onACPower ? "bolt.fill" : "battery.75percent",
                    label: "Battery",
                    value: batteryMenuValue,
                    tint: DeckTheme.statusNormal
                )
            }

            if store.thermal.available {
                Spacer(minLength: 8)
                MiniTelemetry(
                    symbol: thermalSymbol,
                    label: "Thermal",
                    value: store.thermal.displayName,
                    tint: thermalTint
                )
            }
        }
    }

    private var batteryMenuValue: String {
        let level = DeckFormat.percent(store.battery.percentage)
        guard store.battery.temperatureAvailable else { return level }
        return "\(level) · \(DeckFormat.temperatureCelsius(store.battery.temperatureCelsius))"
    }

    private var thermalSymbol: String {
        switch store.thermal.level {
        case .nominal: "thermometer.low"
        case .fair: "thermometer.medium"
        case .serious, .critical: "thermometer.high"
        case .unavailable: "thermometer"
        }
    }

    private var thermalTint: Color {
        switch store.thermal.level {
        case .nominal: DeckTheme.statusNormal
        case .fair: DeckTheme.statusElevated
        case .serious: DeckTheme.statusHigh
        case .critical: DeckTheme.statusCritical
        case .unavailable: DeckTheme.statusUnavailable
        }
    }
}

private struct MenuMetricRow: View {
    let label: String
    let value: String
    let history: [MetricSample]
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DeckTheme.secondaryText)
                .frame(width: 54, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(DeckTheme.primaryText)
                .frame(width: 58, alignment: .trailing)
                .contentTransition(.numericText())

            SparklineView(samples: history, fixedRange: 0...100, tint: tint)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
    }
}

private struct MiniTelemetry: View {
    let symbol: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(DeckTheme.mutedText)
                Text(value)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DeckTheme.secondaryText)
            }
        }
    }
}

private struct MenuActionRow: View {
    let symbol: String
    let title: String
    var destructive = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(destructive ? Color.red.opacity(0.88) : DeckTheme.secondaryText)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(destructive ? Color.red.opacity(0.92) : DeckTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 9)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(hovering ? Color.white.opacity(0.05) : Color.clear)
        }
        .onHover { hovering = $0 }
    }
}
