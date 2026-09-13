import SwiftUI

struct OverviewView: View {
    @ObservedObject var store: SystemMonitorStore
    @Binding var selection: DeckSection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cpuAverage: Double {
        store.average(of: store.cpuHistory, fallback: store.cpuUsage)
    }

    private var cpuPeak: Double {
        store.peak(of: store.cpuHistory, fallback: store.cpuUsage)
    }

    private var cpuStatus: MetricStatus {
        MetricStatusEvaluator.cpu(
            rollingAverage: cpuAverage,
            hasSamples: store.cpuHistory.count >= 5
        )
    }

    private var memoryStatus: MetricStatus {
        MetricStatusEvaluator.memoryPressure(store.memoryPressure)
    }

    private var diskStatus: MetricStatus {
        MetricStatusEvaluator.disk(
            usagePercent: store.disk.usagePercent,
            totalBytes: store.disk.totalBytes
        )
    }

    private var powerSummary: String {
        guard store.battery.available else { return "N/A" }
        var parts = [DeckFormat.percent(store.battery.percentage), store.battery.state]
        if let power = store.battery.powerWatts {
            parts.append(DeckFormat.power(power))
        }
        return parts.joined(separator: " · ")
    }

    private func topProcesses(limit: Int) -> [ProcessMetric] {
        Array(
            store.processes
                .sorted { $0.cpuTotalPercent > $1.cpuTotalPercent }
                .prefix(max(1, limit))
        )
    }

    private func processRowCount(for height: CGFloat) -> Int {
        switch height {
        case 1080...: 12
        case 920..<1080: 10
        case 780..<920: 8
        default: 6
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let processLimit = processRowCount(for: proxy.size.height)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    healthRail

                    HStack(alignment: .top, spacing: 16) {
                        cpuHero
                            .frame(maxWidth: .infinity)
                            .onTapGesture { navigate(.performance) }
                            .accessibilityAddTraits(.isButton)
                            .help("Open Performance")
                            .deckInteractive(tint: DeckTheme.accent)

                        machineSummary
                            .frame(width: 320)
                            .onTapGesture { navigate(.hardware) }
                            .accessibilityAddTraits(.isButton)
                            .help("Open Hardware")
                            .deckInteractive(tint: DeckTheme.indigo)
                    }

                    telemetryRail

                    resourceTable(limit: processLimit)
                        .frame(minHeight: max(280, proxy.size.height - 590), alignment: .top)
                }
                .padding(22)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
            }
        }
    }

    private func navigate(_ section: DeckSection) {
        if reduceMotion {
            selection = section
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                selection = section
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            SectionHeader(
                title: "Overview",
                subtitle: "Current system state and the resources driving it"
            )

            Spacer()

            HStack(spacing: 14) {
                if let lastRefresh = store.lastRefresh {
                    Text("Updated \(lastRefresh.formatted(date: .omitted, time: .standard))")
                        .font(.system(size: 10))
                        .foregroundStyle(DeckTheme.mutedText)
                }

                MonitoringIndicator(active: store.isMonitoring)
            }
        }
    }

    private var healthRail: some View {
        DataSurface(padding: 12, tint: DeckTheme.accent) {
            HStack(spacing: 0) {
                HealthItem(
                    title: "CPU",
                    status: cpuStatus,
                    detail: "\(DeckFormat.percent(cpuAverage)) average"
                )
                RailDivider()
                HealthItem(
                    title: "Memory",
                    status: memoryStatus,
                    detail: store.memoryPressure.available
                        ? "\(DeckFormat.percent(store.memoryPressure.headroomPercent)) headroom"
                        : "Pressure unavailable"
                )
                RailDivider()
                HealthItem(
                    title: "Storage",
                    status: diskStatus,
                    detail: DeckFormat.percent(store.disk.usagePercent)
                )
                RailDivider()

                HStack(spacing: 7) {
                    Image(systemName: store.network.available ? "network" : "network.slash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(store.network.available ? DeckTheme.aqua : DeckTheme.statusUnavailable)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DeckTheme.primaryText)
                        Text(
                            store.network.available
                                ? "\(store.network.interface) · ↓ \(DeckFormat.rate(store.network.downloadBytesPerSecond))"
                                : "Telemetry unavailable"
                        )
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(DeckTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .help("Current traffic on the primary network interface.")
            }
        }
    }

    private var cpuHero: some View {
        Panel(padding: 18, elevated: true, tint: DeckTheme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text("CPU utilization")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DeckTheme.secondaryText)

                            MetricInfoIcon(
                                text: "Share of total CPU capacity across all logical CPUs, normalized to 0–100%."
                            )
                        }

                        Text(DeckFormat.percent(store.cpuUsage))
                            .font(.system(size: 46, weight: .medium, design: .monospaced))
                            .foregroundStyle(DeckTheme.primaryText)
                            .contentTransition(.numericText())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(store.hardware.processor)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DeckTheme.primaryText)
                        Text("\(max(1, store.hardware.logicalCPUCount)) logical CPUs · \(store.hardware.architecture.uppercased())")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(DeckTheme.mutedText)
                    }
                }

                HStack(spacing: 0) {
                    HeroDatum(label: "Average", value: DeckFormat.percent(cpuAverage))
                    RailDivider(height: 32)
                    HeroDatum(label: "Peak", value: DeckFormat.percent(cpuPeak))
                    RailDivider(height: 32)
                    HeroDatum(label: "Sample", value: String(format: "%.0fs", store.refreshInterval))
                    RailDivider(height: 32)
                    HeroDatum(
                        label: "Range",
                        value: DeckFormat.historyRange(store.historyWindow(of: store.cpuHistory))
                    )
                    Spacer(minLength: 0)
                }

                SparklineView(
                    samples: store.cpuHistory,
                    fixedRange: 0...100,
                    tint: DeckTheme.accent
                )
                .frame(height: 110)

                HStack {
                    Text("Older")
                    Spacer()
                    Text("Now")
                }
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(DeckTheme.mutedText)
            }
        }
    }

    private var machineSummary: some View {
        DataSurface(padding: 18, tint: DeckTheme.indigo) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.hardware.computerName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DeckTheme.primaryText)
                            .lineLimit(1)
                        Text(store.hardware.modelIdentifier)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DeckTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DeckTheme.accent)
                }

                DeckDivider()

                MachineRow(label: "Processor", value: store.hardware.processor)
                MachineRow(label: "Memory", value: DeckFormat.bytes(store.hardware.physicalMemoryBytes))
                MachineRow(label: "macOS", value: store.hardware.macOSVersion)
                MachineRow(label: "Uptime", value: DeckFormat.uptime(ProcessInfo.processInfo.systemUptime))
                MachineRow(label: "Network", value: store.network.available ? store.network.interface : "N/A")
                MachineRow(label: "Power", value: powerSummary)
                MachineRow(
                    label: "Thermal",
                    value: thermalSummary
                )
            }
        }
    }

    private var thermalSummary: String {
        guard store.thermal.available else { return "N/A" }
        return store.thermal.compactSummary
    }

    private var telemetryRail: some View {
        DataSurface(padding: 0, tint: DeckTheme.cyan) {
            HStack(spacing: 0) {
                TelemetryColumn(
                    title: "Memory",
                    value: DeckFormat.percent(store.memory.usagePercent),
                    detail: "\(DeckFormat.bytes(store.memory.usedBytes)) of \(DeckFormat.bytes(store.memory.totalBytes))",
                    footer: store.memoryPressure.available
                        ? "Pressure \(store.memoryPressure.level.rawValue)"
                        : "Pressure unavailable",
                    history: store.memoryHistory,
                    fixedRange: 0...100,
                    tint: DeckTheme.violet
                )
                .onTapGesture { navigate(.memory) }

                RailDivider(stretch: true)

                TelemetryColumn(
                    title: "GPU",
                    value: store.gpu.available ? DeckFormat.percent(store.gpu.utilizationPercent) : "N/A",
                    detail: store.gpu.inUseMemoryBytes > 0
                        ? "Memory \(DeckFormat.bytes(store.gpu.inUseMemoryBytes))"
                        : "\(store.gpu.coreCount) cores",
                    footer: store.gpu.available ? store.gpu.model : "Telemetry unavailable",
                    history: store.gpuHistory,
                    fixedRange: 0...100,
                    tint: DeckTheme.cyan
                )
                .onTapGesture { navigate(.performance) }

                RailDivider(stretch: true)

                TelemetryColumn(
                    title: "Network",
                    value: store.network.available ? DeckFormat.rate(store.network.downloadBytesPerSecond) : "N/A",
                    detail: store.network.available
                        ? "Upload \(DeckFormat.rate(store.network.uploadBytesPerSecond))"
                        : "No active interface",
                    footer: store.network.available ? store.network.interface : "Telemetry unavailable",
                    history: store.downloadHistory,
                    fixedRange: nil,
                    tint: DeckTheme.aqua
                )
                .onTapGesture { navigate(.network) }
            }
        }
    }

    private func resourceTable(limit: Int) -> some View {
        let visibleProcesses = topProcesses(limit: limit)

        return DataSurface(padding: 0, tint: DeckTheme.indigo) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Top resource users")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DeckTheme.primaryText)
                        Text("CPU Total is normalized to the Mac's full logical-CPU capacity")
                            .font(.system(size: 9))
                            .foregroundStyle(DeckTheme.mutedText)
                    }
                    Spacer()
                    Text("CPU TOTAL    CORE       MEMORY")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DeckTheme.mutedText)
                }
                .padding(.horizontal, 15)
                .frame(height: 48)

                DeckDivider()

                if visibleProcesses.isEmpty {
                    Text("Waiting for process telemetry…")
                        .font(.system(size: 11))
                        .foregroundStyle(DeckTheme.mutedText)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                } else {
                    ForEach(Array(visibleProcesses.enumerated()), id: \.element.id) { index, process in
                        OverviewProcessRow(index: index + 1, process: process) {
                            navigate(.processes)
                        }
                        if process.id != visibleProcesses.last?.id {
                            DeckDivider()
                                .padding(.leading, 15)
                        }
                    }
                }

                Spacer(minLength: 0)

                DeckDivider()

                Button {
                    navigate(.processes)
                } label: {
                    HStack(spacing: 6) {
                        Text("View all processes")
                            .font(.system(size: 10.5, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(DeckTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .deckRowHover(tint: DeckTheme.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .deckInteractive(tint: DeckTheme.indigo)
        .onTapGesture { navigate(.processes) }
        .accessibilityAddTraits(.isButton)
        .help("Open Processes")
    }
}

private struct HealthItem: View {
    let title: String
    let status: MetricStatus
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(status.severity.deckTint)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DeckTheme.primaryText)
                    Text(status.label)
                        .font(.system(size: 10))
                        .foregroundStyle(DeckTheme.secondaryText)
                }
                Text(detail)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(DeckTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(status.explanation)
    }

    private var symbol: String {
        switch status.severity {
        case .normal: "checkmark.circle.fill"
        case .elevated: "exclamationmark.circle.fill"
        case .high, .critical: "exclamationmark.triangle.fill"
        case .unavailable: "questionmark.circle"
        }
    }
}

private struct HeroDatum: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(DeckTheme.mutedText)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(DeckTheme.primaryText)
        }
        .frame(minWidth: 74, alignment: .leading)
    }
}

private struct MachineRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DeckTheme.mutedText)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DeckTheme.secondaryText)
                .lineLimit(1)
        }
    }
}

private struct TelemetryColumn: View {
    let title: String
    let value: String
    let detail: String
    let footer: String
    let history: [MetricSample]
    let fixedRange: ClosedRange<Double>?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DeckTheme.secondaryText)

            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundStyle(DeckTheme.primaryText)
                    .contentTransition(.numericText())
                Spacer()
                Text(detail)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(DeckTheme.secondaryText)
                    .lineLimit(1)
            }

            SparklineView(samples: history, fixedRange: fixedRange, tint: tint)
                .frame(height: 54)

            Text(footer)
                .font(.system(size: 9))
                .foregroundStyle(DeckTheme.mutedText)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .deckRowHover(tint: tint)
    }
}

private struct OverviewProcessRow: View {
    let index: Int
    let process: ProcessMetric
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .frame(width: 24, alignment: .leading)
                .foregroundStyle(DeckTheme.mutedText)

            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(DeckTheme.primaryText)
                    .lineLimit(1)
                Text("PID \(process.pid) · \(process.elapsedTime)")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(DeckTheme.mutedText)
            }

            Spacer()

            Text(String(format: "%.1f%%", process.cpuTotalPercent))
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(DeckTheme.cyan)
            Text(String(format: "%.1f%%", process.coreUsagePercent))
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(DeckTheme.secondaryText)
            Text(DeckFormat.bytes(process.memoryBytes))
                .frame(width: 86, alignment: .trailing)
                .foregroundStyle(DeckTheme.secondaryText)
        }
        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
        .padding(.horizontal, 15)
        .frame(height: 40)
        .contentShape(Rectangle())
        .deckRowHover(tint: DeckTheme.indigo)
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Open the full process list")
    }
}

private struct RailDivider: View {
    var height: CGFloat = 34
    var stretch = false

    var body: some View {
        Rectangle()
            .fill(DeckTheme.hairline)
            .frame(width: 1, height: stretch ? nil : height)
            .padding(.horizontal, stretch ? 0 : 14)
    }
}
