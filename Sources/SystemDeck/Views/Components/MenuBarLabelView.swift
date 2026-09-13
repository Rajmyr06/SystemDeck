import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var store: SystemMonitorStore

    @AppStorage("menuBarMetric.cpu") private var showCPU = true
    @AppStorage("menuBarMetric.gpu") private var showGPU = false
    @AppStorage("menuBarMetric.memory") private var showMemory = false
    @AppStorage("menuBarMetric.network") private var showNetwork = false
    @AppStorage("menuBarMetric.battery") private var showBattery = false
    @AppStorage("menuBarMetric.thermal") private var showThermal = false

    var body: some View {
        Group {
            if summaryParts.isEmpty {
                Image(systemName: "waveform.path.ecg")
            } else {
                Text(summaryParts.joined(separator: " · "))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .accessibilityLabel(accessibilitySummary)
    }

    private var summaryParts: [String] {
        var parts: [String] = []

        if showCPU {
            parts.append("CPU \(DeckFormat.percent(store.cpuUsage))")
        }
        if showGPU, store.gpu.available {
            parts.append("GPU \(DeckFormat.percent(store.gpu.utilizationPercent))")
        }
        if showMemory {
            parts.append("RAM \(DeckFormat.percent(store.memory.usagePercent))")
        }
        if showNetwork, store.network.available {
            parts.append("↓\(compactRate(store.network.downloadBytesPerSecond)) ↑\(compactRate(store.network.uploadBytesPerSecond))")
        }
        if showBattery, store.battery.available {
            parts.append("BAT \(DeckFormat.percent(store.battery.percentage))")
        }
        if showThermal, store.thermal.available {
            parts.append("THERM \(store.thermal.displayName)")
        }

        return Array(parts.prefix(3))
    }

    private var accessibilitySummary: String {
        guard !summaryParts.isEmpty else { return "SystemDeck" }
        return "SystemDeck, " + summaryParts.joined(separator: ", ")
    }

    private func compactRate(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0" }
        if value >= 1_000_000_000 { return String(format: "%.1fG", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0fK", value / 1_000) }
        return String(format: "%.0fB", value)
    }
}
