import SwiftUI

struct PerformanceView: View {
    @ObservedObject var store: SystemMonitorStore

    private var cpuAverage: Double { store.average(of: store.cpuHistory, fallback: store.cpuUsage) }
    private var cpuPeak: Double { store.peak(of: store.cpuHistory, fallback: store.cpuUsage) }
    private var gpuAverage: Double { store.average(of: store.gpuHistory, fallback: store.gpu.utilizationPercent) }
    private var gpuPeak: Double { store.peak(of: store.gpuHistory, fallback: store.gpu.utilizationPercent) }
    private var downloadPeak: Double { store.peak(of: store.downloadHistory, fallback: store.network.downloadBytesPerSecond) }
    private var uploadPeak: Double { store.peak(of: store.uploadHistory, fallback: store.network.uploadBytesPerSecond) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        SectionHeader(
                            title: "Performance",
                            subtitle: "Rolling telemetry for CPU, GPU, memory, and network throughput"
                        )
                        Spacer()
                        HStack(spacing: 12) {
                            Text("Sample \(String(format: "%.0fs", store.refreshInterval))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(DeckTheme.mutedText)
                            MonitoringIndicator(active: store.isMonitoring)
                        }
                    }

                    contextRail

                    PerformanceChart(
                        title: "CPU utilization",
                        value: DeckFormat.percent(store.cpuUsage),
                        samples: store.cpuHistory,
                        fixedRange: 0...100,
                        tint: DeckTheme.accent,
                        axisKind: .percentage,
                        help: "Total CPU capacity across all logical CPUs, normalized to 0–100%."
                    )
                    .frame(minHeight: 300)

                    CoreCPUGrid(cores: store.cpuCores)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                        spacing: 16
                    ) {
                        PerformanceChart(
                            title: "GPU utilization",
                            value: store.gpu.available ? DeckFormat.percent(store.gpu.utilizationPercent) : "N/A",
                            samples: store.gpuHistory,
                            fixedRange: 0...100,
                            tint: DeckTheme.cyan,
                            axisKind: .percentage,
                            help: "GPU device utilization reported by IOKit. Renderer and tiler values appear only when available."
                        )

                        PerformanceChart(
                            title: "Memory usage",
                            value: DeckFormat.percent(store.memory.usagePercent),
                            samples: store.memoryHistory,
                            fixedRange: 0...100,
                            tint: DeckTheme.violet,
                            axisKind: .percentage,
                            help: "Used unified memory derived from Mach VM counters."
                        )

                        PerformanceChart(
                            title: "Network download",
                            value: store.network.available ? DeckFormat.rate(store.network.downloadBytesPerSecond) : "N/A",
                            samples: store.downloadHistory,
                            tint: DeckTheme.aqua,
                            axisKind: .rate,
                            help: "Current receive throughput on the primary network interface."
                        )

                        PerformanceChart(
                            title: "Network upload",
                            value: store.network.available ? DeckFormat.rate(store.network.uploadBytesPerSecond) : "N/A",
                            samples: store.uploadHistory,
                            tint: DeckTheme.indigo,
                            axisKind: .rate,
                            help: "Current transmit throughput on the primary network interface."
                        )
                    }
                    .frame(minHeight: max(420, proxy.size.height - 430), alignment: .top)

                    if store.gpu.available {
                        gpuFacts
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
            }
        }
    }

    private var contextRail: some View {
        DataSurface(padding: 12, tint: DeckTheme.indigo) {
            HStack(spacing: 0) {
                PerformanceDatum(label: "CPU average", value: DeckFormat.percent(cpuAverage))
                PerformanceDivider()
                PerformanceDatum(label: "CPU peak", value: DeckFormat.percent(cpuPeak))
                PerformanceDivider()
                PerformanceDatum(label: "GPU average", value: store.gpu.available ? DeckFormat.percent(gpuAverage) : "N/A")
                PerformanceDivider()
                PerformanceDatum(label: "GPU peak", value: store.gpu.available ? DeckFormat.percent(gpuPeak) : "N/A")
                PerformanceDivider()
                PerformanceDatum(label: "Peak download", value: DeckFormat.rate(downloadPeak))
                PerformanceDivider()
                PerformanceDatum(label: "Peak upload", value: DeckFormat.rate(uploadPeak))
                PerformanceDivider()
                PerformanceDatum(label: "Range", value: DeckFormat.historyRange(store.historyWindow(of: store.cpuHistory)))
            }
        }
    }

    private var gpuFacts: some View {
        DataSurface(padding: 12, tint: DeckTheme.cyan) {
            HStack(spacing: 0) {
                PerformanceDatum(label: "GPU device", value: DeckFormat.percent(store.gpu.utilizationPercent))

                if store.gpu.hasDistinctRendererMetric {
                    PerformanceDivider()
                    PerformanceDatum(label: "Renderer", value: DeckFormat.percent(store.gpu.rendererPercent))
                }

                if store.gpu.hasDistinctTilerMetric {
                    PerformanceDivider()
                    PerformanceDatum(label: "Tiler", value: DeckFormat.percent(store.gpu.tilerPercent))
                }

                if store.gpu.inUseMemoryBytes > 0 {
                    PerformanceDivider()
                    PerformanceDatum(label: "GPU memory", value: DeckFormat.bytes(store.gpu.inUseMemoryBytes))
                }

                if store.gpu.coreCount > 0 {
                    PerformanceDivider()
                    PerformanceDatum(label: "GPU cores", value: "\(store.gpu.coreCount)")
                }

                Spacer(minLength: 0)
            }
        }
        .help("Renderer and tiler appear only when the driver exposes values distinct from overall device utilization.")
    }
}

private struct PerformanceDatum: View {
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
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PerformanceDivider: View {
    var body: some View {
        Rectangle()
            .fill(DeckTheme.hairline)
            .frame(width: 1, height: 34)
            .padding(.horizontal, 10)
    }
}
