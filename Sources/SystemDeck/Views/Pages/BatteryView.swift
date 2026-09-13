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
                SectionHeader(title: "Battery", subtitle: "Power state, electrical telemetry, and battery health")

                if store.battery.available {
                    PerformanceChart(
                        title: "Battery level",
                        value: DeckFormat.percent(store.battery.percentage),
                        samples: store.batteryHistory,
                        fixedRange: 0...100,
                        tint: DeckTheme.accent,
                        axisKind: .percentage,
                        help: "Battery percentage from macOS power-management telemetry. Battery state and electrical readings refresh about every 5 seconds."
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

                    if store.battery.hasElectricalTelemetry {
                        electricalTelemetry
                    }

                    healthAndThermalRow
                } else {
                    DataSurface(tint: DeckTheme.accent) {
                        HStack(spacing: 12) {
                            Image(systemName: "battery.slash")
                                .foregroundStyle(DeckTheme.mutedText)
                            Text("Battery telemetry is unavailable on this Mac.")
                                .font(.system(size: 13))
                                .foregroundStyle(DeckTheme.secondaryText)
                        }
                    }

                    healthAndThermalRow
                }
            }
            .padding(22)
        }
    }

    private var electricalTelemetry: some View {
        DataSurface(tint: DeckTheme.cyan) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Electrical")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DeckTheme.primaryText)
                        Text("Battery-side voltage, current, and power flow")
                            .font(.system(size: 10))
                            .foregroundStyle(DeckTheme.mutedText)
                    }
                    Spacer()
                    Text("LIVE · ~5s")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DeckTheme.cyan)
                }

                if let power = store.battery.powerWatts {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(electricalPowerLabel.uppercased())
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DeckTheme.secondaryText)
                            Text(DeckFormat.power(power))
                                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DeckTheme.primaryText)
                                .contentTransition(.numericText())
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(electricalFlowTitle)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DeckTheme.primaryText)
                            Text(electricalFlowDetail)
                                .font(.system(size: 10))
                                .foregroundStyle(DeckTheme.secondaryText)
                        }
                    }

                    DeckDivider()
                }

                if store.batteryPowerHistory.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(electricalHistoryLabel)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(DeckTheme.mutedText)
                        SparklineView(samples: store.batteryPowerHistory, tint: DeckTheme.cyan)
                            .frame(height: 52)
                    }

                    DeckDivider()
                }

                HStack(spacing: 0) {
                    if let voltage = store.battery.voltageVolts {
                        ElectricalMetric(label: "Voltage", value: DeckFormat.voltage(voltage), detail: "Battery pack")
                    }
                    if store.battery.voltageVolts != nil, store.battery.currentAmps != nil {
                        ElectricalDivider()
                    }
                    if let current = store.battery.currentAmps {
                        ElectricalMetric(label: "Current", value: DeckFormat.current(current), detail: currentDetail)
                    }
                    if store.battery.currentAmps != nil, store.battery.adapterWatts != nil {
                        ElectricalDivider()
                    }
                    if let adapter = store.battery.adapterWatts {
                        ElectricalMetric(label: "Adapter rating", value: DeckFormat.power(adapter), detail: "Rated capability")
                    }
                }

                if let voltage = store.battery.voltageVolts,
                   let current = store.battery.currentAmps,
                   store.battery.powerWatts != nil {
                    Text("Battery power is calculated from \(DeckFormat.voltage(voltage)) × \(DeckFormat.current(current)). Adapter rating is capability, not the Mac's current wall-power draw.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(DeckTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var electricalHistoryLabel: String {
        guard let first = store.batteryPowerHistory.first?.timestamp,
              let last = store.batteryPowerHistory.last?.timestamp else {
            return "Power trend"
        }
        return "Power trend · \(DeckFormat.historyRange(last.timeIntervalSince(first)))"
    }

    private var electricalPowerLabel: String {
        switch store.battery.state {
        case "Discharging": return "Battery output"
        case "Charging": return "Battery charge"
        default: return "Battery power"
        }
    }

    private var electricalFlowTitle: String {
        switch store.battery.state {
        case "Charging": return "Charging"
        case "Discharging": return "Discharging"
        case "Charged": return "Charged"
        default: return store.battery.onACPower ? "External power" : "Battery power"
        }
    }

    private var electricalFlowDetail: String {
        if store.battery.onACPower {
            return store.battery.state == "Charging" ? "AC adapter → battery" : "Powered by AC adapter"
        }
        return "Battery → system"
    }

    private var currentDetail: String {
        switch store.battery.state {
        case "Charging": return "Into battery"
        case "Discharging": return "From battery"
        default: return "Battery current"
        }
    }

    private var healthAndThermalRow: some View {
        HStack(alignment: .top, spacing: 16) {
            if store.battery.hasHealthTelemetry {
                batteryHealthCard
                    .frame(maxWidth: .infinity, alignment: .top)
            }

            thermalConditionCard
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var batteryHealthCard: some View {
        DataSurface(tint: DeckTheme.violet) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Battery health")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DeckTheme.primaryText)

                    if let summary = batteryHealthSummary {
                        Text(summary)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DeckTheme.violet)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 8)

                if let cycleCount = store.battery.cycleCount {
                    PowerMetricRow(label: "Cycle count", value: String(cycleCount))
                }
                if let capacity = store.battery.fullChargeCapacityMah {
                    PowerMetricRow(label: "Full capacity", value: DeckFormat.capacityMah(capacity))
                }
                if let capacity = store.battery.designCapacityMah {
                    PowerMetricRow(label: "Design capacity", value: DeckFormat.capacityMah(capacity))
                }
                if let healthPercent = store.battery.healthPercent {
                    PowerMetricRow(
                        label: "Maximum capacity",
                        value: String(format: "%.0f%%", min(100, max(0, healthPercent)))
                    )
                }
                if let health = store.battery.healthText {
                    PowerMetricRow(label: "Condition", value: health, showDivider: false)
                }
            }
        }
    }

    private var batteryHealthSummary: String? {
        let percent = store.battery.healthPercent.map {
            String(format: "%.0f%%", min(100, max(0, $0)))
        }
        let condition = store.battery.healthText

        switch (percent, condition) {
        case let (.some(percent), .some(condition)):
            return "\(percent) · \(condition)"
        case let (.some(percent), .none):
            return percent
        case let (.none, .some(condition)):
            return condition
        case (.none, .none):
            return nil
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

private struct ElectricalMetric: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(DeckTheme.secondaryText)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(DeckTheme.primaryText)
                .contentTransition(.numericText())
            Text(detail)
                .font(.system(size: 9.5))
                .foregroundStyle(DeckTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ElectricalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 48)
            .padding(.horizontal, 14)
    }
}

private struct PowerMetricRow: View {
    let label: String
    let value: String
    var showDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(DeckTheme.secondaryText)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DeckTheme.primaryText)
            }
            .padding(.vertical, 10)

            if showDivider {
                DeckDivider()
            }
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
