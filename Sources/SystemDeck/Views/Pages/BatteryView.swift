import SwiftUI

struct BatteryView: View {
    @ObservedObject var store: SystemMonitorStore

    private var levelLabel: String {
        let state = store.battery.state.lowercased()
        return (state.contains("charging") || state.contains("charged")) ? "Charge" : "Level"
    }

    private var thermalHeadline: String {
        switch store.thermal.level {
        case .nominal:
            return "macOS is not reporting a thermal constraint"
        case .fair:
            return "Thermal pressure is elevated"
        case .serious:
            return "Thermal pressure is high"
        case .critical:
            return "Thermal pressure is critical"
        case .unavailable:
            return "Thermal condition is unavailable"
        }
    }

    private var thermalDetail: String {
        switch store.thermal.level {
        case .nominal:
            return "The Mac is operating within its normal thermal range, with no system-level performance limit currently indicated."
        case .fair:
            return "The Mac is managing more heat than usual. Sustained workloads can continue, but thermal pressure is worth watching."
        case .serious:
            return "macOS may reduce sustained CPU or GPU performance until the system cools. Reducing heavy workloads can help."
        case .critical:
            return "Significant performance limits may be applied until thermal conditions improve. Let the Mac cool and reduce sustained load."
        case .unavailable:
            return "macOS did not provide a system thermal-pressure signal for this sample."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Battery", subtitle: "Power state and system thermal condition")

                if store.battery.available {
                    PerformanceChart(
                        title: "Battery level",
                        value: DeckFormat.percent(store.battery.percentage),
                        samples: store.batteryHistory,
                        fixedRange: 0...100,
                        tint: DeckTheme.accent,
                        axisKind: .percentage,
                        help: "Battery percentage from macOS power-management telemetry. Battery history updates on the slower 30-second collector cadence."
                    )

                    DataSurface(tint: DeckTheme.accent) {
                        HStack(spacing: 0) {
                            BatteryStat(title: "State", value: store.battery.state, tint: DeckTheme.accent)
                            BatteryDivider()
                            BatteryStat(
                                title: "Remaining",
                                value: store.battery.timeRemaining,
                                tint: DeckTheme.cyan,
                                help: "macOS-provided remaining-time estimate. A dash means the system did not provide a reliable estimate."
                            )
                            BatteryDivider()
                            BatteryStat(title: "Power source", value: store.battery.onACPower ? "AC Adapter" : "Battery", tint: DeckTheme.violet)
                            BatteryDivider()
                            BatteryStat(title: levelLabel, value: DeckFormat.percent(store.battery.percentage), tint: DeckTheme.aqua)
                            BatteryDivider()
                            BatteryStat(
                                title: "Thermal",
                                value: store.thermal.available ? store.thermal.displayName : "N/A",
                                tint: thermalTint,
                                help: store.thermal.explanation
                            )
                        }
                    }

                    thermalConditionCard
                } else {
                    DataSurface(tint: DeckTheme.accent) {
                        HStack(spacing: 12) {
                            Image(systemName: "battery.slash")
                                .foregroundStyle(DeckTheme.mutedText)
                            Text("Battery telemetry is unavailable on this Mac.")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(DeckTheme.secondaryText)
                        }
                    }

                    thermalConditionCard
                }
            }
            .padding(22)
        }
    }

    private var thermalConditionCard: some View {
        SystemContextCard(
            title: "Thermal condition",
            status: store.thermal.available ? store.thermal.displayName : "Unavailable",
            headline: thermalHeadline,
            detail: thermalDetail,
            note: nil,
            symbol: thermalSymbol,
            tint: thermalTint
        )
    }

    private var thermalSymbol: String {
        switch store.thermal.level {
        case .nominal: "checkmark.circle.fill"
        case .fair: "exclamationmark.circle.fill"
        case .serious: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        case .unavailable: "questionmark.circle"
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

private struct BatteryStat: View {
    let title: String
    let value: String
    let tint: Color
    var help: String? = nil

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 5, height: 5).shadow(color: tint.opacity(0.6), radius: 4)
                if let help {
                    MetricInfoIcon(text: help)
                }
            }
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(DeckTheme.secondaryText)
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(DeckTheme.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BatteryDivider: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 50).padding(.horizontal, 10)
    }
}
