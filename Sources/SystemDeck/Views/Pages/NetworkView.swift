import SwiftUI

struct NetworkView: View {
    @ObservedObject var store: SystemMonitorStore

    private var downloadPeak: Double {
        store.peak(of: store.downloadHistory, fallback: store.network.downloadBytesPerSecond)
    }

    private var uploadPeak: Double {
        store.peak(of: store.uploadHistory, fallback: store.network.uploadBytesPerSecond)
    }

    private var historyWindow: String {
        DeckFormat.durationCompact(
            max(
                store.historyWindow(of: store.downloadHistory),
                store.historyWindow(of: store.uploadHistory)
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeader(title: "Network", subtitle: "Primary-interface throughput and rolling history")
                    Spacer()
                    Text("Interface  \(store.network.interface)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DeckTheme.secondaryText)
                }

                DataSurface(tint: DeckTheme.aqua) {
                    HStack(spacing: 0) {
                        NetworkStat(
                            title: "Download now",
                            value: store.network.available ? DeckFormat.rate(store.network.downloadBytesPerSecond) : "N/A",
                            tint: DeckTheme.cyan,
                            help: "Current receive throughput calculated from byte-counter deltas between samples."
                        )
                        GlassDivider()
                        NetworkStat(
                            title: "Upload now",
                            value: store.network.available ? DeckFormat.rate(store.network.uploadBytesPerSecond) : "N/A",
                            tint: DeckTheme.indigo,
                            help: "Current transmit throughput calculated from byte-counter deltas between samples."
                        )
                        GlassDivider()
                        NetworkStat(
                            title: "Peak ↓",
                            value: DeckFormat.rate(downloadPeak),
                            tint: DeckTheme.aqua,
                            help: "Highest download sample inside the current rolling history window."
                        )
                        GlassDivider()
                        NetworkStat(
                            title: "Peak ↑",
                            value: DeckFormat.rate(uploadPeak),
                            tint: DeckTheme.accent,
                            help: "Highest upload sample inside the current rolling history window."
                        )
                        GlassDivider()
                        NetworkStat(
                            title: "History",
                            value: historyWindow,
                            tint: DeckTheme.violet,
                            help: "Elapsed time covered by the currently retained samples. The store keeps up to 120 samples."
                        )
                    }
                    .frame(maxWidth: .infinity)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    PerformanceChart(
                        title: "Download",
                        value: store.network.available ? DeckFormat.rate(store.network.downloadBytesPerSecond) : "N/A",
                        samples: store.downloadHistory,
                        tint: DeckTheme.cyan,
                        axisKind: .rate,
                        help: "Receive throughput on \(store.network.interface). Axis labels automatically scale from B/s to KB/s, MB/s, or GB/s."
                    )
                    PerformanceChart(
                        title: "Upload",
                        value: store.network.available ? DeckFormat.rate(store.network.uploadBytesPerSecond) : "N/A",
                        samples: store.uploadHistory,
                        tint: DeckTheme.indigo,
                        axisKind: .rate,
                        help: "Transmit throughput on \(store.network.interface). Axis labels automatically scale from B/s to KB/s, MB/s, or GB/s."
                    )
                }

                DataSurface(tint: DeckTheme.indigo) {
                    HStack(spacing: 0) {
                        NetworkStat(title: "Interface", value: store.network.interface, tint: DeckTheme.aqua)
                        GlassDivider()
                        NetworkStat(title: "Received total", value: DeckFormat.bytes(store.network.receivedBytes), tint: DeckTheme.cyan)
                        GlassDivider()
                        NetworkStat(title: "Sent total", value: DeckFormat.bytes(store.network.sentBytes), tint: DeckTheme.indigo)
                        GlassDivider()
                        NetworkStat(title: "Sample", value: String(format: "%.0fs", store.refreshInterval), tint: DeckTheme.accent)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(22)
        }
    }
}

private struct NetworkStat: View {
    let title: String
    let value: String
    let tint: Color
    var help: String? = nil

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DeckTheme.secondaryText)
                if let help { MetricInfoIcon(text: help) }
            }
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(DeckTheme.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(DeckTheme.hairline)
            .frame(width: 1, height: 50)
            .padding(.horizontal, 12)
    }
}
