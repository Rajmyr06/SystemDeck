import SwiftUI

struct CompactView: View {
    @ObservedObject var store: SystemMonitorStore

    var body: some View {
        ZStack {
            DeckBackground()

            DataSurface(padding: 0, tint: DeckTheme.accent) {
                VStack(spacing: 0) {
                    header
                    DeckDivider()
                    metricRows
                    DeckDivider()
                    networkFooter
                }
            }
            .padding(10)
        }
        .frame(width: 640, height: 278)
        .background {
            CompactWindowBridge()
                .frame(width: 0, height: 0)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DeckTheme.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("SystemDeck")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DeckTheme.primaryText)
                Text(store.hardware.computerName)
                    .font(.system(size: 9))
                    .foregroundStyle(DeckTheme.mutedText)
            }

            Spacer()

            Text("\(String(format: "%.0fs", store.refreshInterval)) sample")
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundStyle(DeckTheme.mutedText)
            MonitoringIndicator(active: store.isMonitoring)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    private var metricRows: some View {
        VStack(spacing: 0) {
            CompactMetric(title: "CPU", value: DeckFormat.percent(store.cpuUsage), history: store.cpuHistory, range: 0...100, tint: DeckTheme.accent)
            CompactMetric(title: "GPU", value: store.gpu.available ? DeckFormat.percent(store.gpu.utilizationPercent) : "N/A", history: store.gpuHistory, range: 0...100, tint: DeckTheme.cyan)
            CompactMetric(title: "Memory", value: DeckFormat.percent(store.memory.usagePercent), history: store.memoryHistory, range: 0...100, tint: DeckTheme.violet)
        }
    }

    private var networkFooter: some View {
        HStack(spacing: 0) {
            CompactNetworkItem(symbol: "arrow.down", label: "Download", value: DeckFormat.rate(store.network.downloadBytesPerSecond), tint: DeckTheme.aqua)
            Spacer(minLength: 20)
            CompactNetworkItem(symbol: "arrow.up", label: "Upload", value: DeckFormat.rate(store.network.uploadBytesPerSecond), tint: DeckTheme.indigo)
            Spacer(minLength: 20)

            if store.battery.available {
                CompactNetworkItem(
                    symbol: store.battery.onACPower ? "bolt.fill" : "battery.75percent",
                    label: "Battery",
                    value: batteryCompactValue,
                    tint: DeckTheme.statusNormal
                )
            }

            Spacer(minLength: 20)
            CompactNetworkItem(
                symbol: thermalSymbol,
                label: store.thermal.available ? store.thermal.shortDetail : "Thermal",
                value: store.thermal.available ? store.thermal.displayName : "N/A",
                tint: thermalTint
            )
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    private var batteryCompactValue: String {
        let level = DeckFormat.percent(store.battery.percentage)
        if let power = store.battery.powerWatts {
            return "\(level) · \(DeckFormat.power(power))"
        }
        return level
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

private struct CompactMetric: View {
    let title: String
    let value: String
    let history: [MetricSample]
    let range: ClosedRange<Double>?
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DeckTheme.secondaryText)
                .frame(width: 66, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(DeckTheme.primaryText)
                .frame(width: 76, alignment: .trailing)
                .contentTransition(.numericText())

            SparklineView(samples: history, fixedRange: range, tint: tint)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .overlay(alignment: .bottom) { DeckDivider().padding(.leading, 16) }
    }
}

private struct CompactNetworkItem: View {
    let symbol: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(DeckTheme.mutedText)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DeckTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}
