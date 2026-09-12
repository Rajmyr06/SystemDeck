import SwiftUI

struct HardwareView: View {
    @ObservedObject var store: SystemMonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Hardware", subtitle: "Machine identity and runtime")

                HStack(alignment: .top, spacing: 16) {
                    identityCard
                        .frame(width: 372)
                    detailsCard
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(22)
        }
    }

    private var identityCard: some View {
        Panel(padding: 24, elevated: true, tint: DeckTheme.indigo) {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(DeckTheme.accent)
                    .frame(height: 76, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.hardware.computerName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DeckTheme.primaryText)
                    Text(store.hardware.modelIdentifier)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DeckTheme.secondaryText)
                }

                DeckDivider()

                IdentityRow(label: "Architecture", value: store.hardware.architecture.uppercased())
                IdentityRow(label: "Processor", value: store.hardware.processor)
                IdentityRow(label: "Memory", value: DeckFormat.bytes(store.hardware.physicalMemoryBytes))
            }
            .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
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

    private var batteryTemperatureTint: Color {
        let value = store.battery.temperatureCelsius
        if value >= 45 { return DeckTheme.statusHigh }
        if value >= 38 { return DeckTheme.statusElevated }
        return DeckTheme.statusNormal
    }

    private var detailsCard: some View {
        DataSurface(padding: 18, tint: DeckTheme.accent) {
            VStack(spacing: 0) {
                HardwareRow(label: "Processor", value: store.hardware.processor, tint: DeckTheme.accent)
                HardwareRow(label: "Logical CPUs", value: String(max(1, store.hardware.logicalCPUCount)), tint: DeckTheme.aqua)
                HardwareRow(label: "Architecture", value: store.hardware.architecture, tint: DeckTheme.indigo)
                HardwareRow(label: "Memory", value: DeckFormat.bytes(store.hardware.physicalMemoryBytes), tint: DeckTheme.violet)
                HardwareRow(label: "macOS", value: store.hardware.macOSVersion, tint: DeckTheme.cyan)
                HardwareRow(label: "Uptime", value: DeckFormat.uptime(ProcessInfo.processInfo.systemUptime), tint: DeckTheme.aqua)
                HardwareRow(
                    label: "Thermal condition",
                    value: store.thermal.available ? store.thermal.compactSummary : "N/A",
                    tint: thermalTint,
                    showDivider: store.battery.temperatureAvailable || store.gpu.available
                )

                if store.battery.temperatureAvailable {
                    HardwareRow(
                        label: "Battery temperature",
                        value: DeckFormat.temperatureCelsius(store.battery.temperatureCelsius),
                        tint: batteryTemperatureTint,
                        showDivider: store.gpu.available
                    )
                }

                if store.gpu.available {
                    HardwareRow(label: "GPU", value: store.gpu.model, tint: DeckTheme.cyan)
                    if store.gpu.coreCount > 0 {
                        HardwareRow(label: "GPU cores", value: String(store.gpu.coreCount), tint: DeckTheme.cyan)
                    }
                    HardwareRow(
                        label: "GPU in-use memory",
                        value: store.gpu.inUseMemoryBytes > 0 ? DeckFormat.bytes(store.gpu.inUseMemoryBytes) : "N/A",
                        tint: DeckTheme.violet
                    )
                    HardwareRow(
                        label: "GPU allocated memory",
                        value: store.gpu.allocatedMemoryBytes > 0 ? DeckFormat.bytes(store.gpu.allocatedMemoryBytes) : "N/A",
                        tint: DeckTheme.indigo,
                        showDivider: false
                    )
                }
            }
        }
    }
}

private struct IdentityRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(DeckTheme.mutedText)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(DeckTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HardwareRow: View {
    let label: String
    let value: String
    let tint: Color
    var showDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DeckTheme.secondaryText)
                    .frame(width: 160, alignment: .leading)
                Text(value)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(DeckTheme.primaryText)
                Spacer()
            }
            .padding(.vertical, 12)

            if showDivider {
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
            }
        }
    }
}
