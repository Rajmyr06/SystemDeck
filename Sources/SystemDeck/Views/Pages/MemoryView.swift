import SwiftUI

struct MemoryView: View {
    @ObservedObject var store: SystemMonitorStore

    private var pressureStatus: MetricStatus {
        MetricStatusEvaluator.memoryPressure(store.memoryPressure)
    }

    private var pressureHeadline: String {
        guard store.memoryPressure.available else { return "Memory pressure is not available right now" }
        let headroom = DeckFormat.percent(store.memoryPressure.headroomPercent)
        switch pressureStatus.severity {
        case .normal:
            return "\(headroom) headroom remains"
        case .elevated:
            return "\(headroom) headroom remains"
        case .high, .critical:
            return "\(headroom) headroom remains"
        case .unavailable:
            return "Memory pressure is not available right now"
        }
    }

    private var pressureDetail: String {
        let usage = "\(DeckFormat.bytes(store.memory.usedBytes)) of \(DeckFormat.bytes(store.memory.totalBytes)) is in use"
        let compressed = "\(DeckFormat.bytes(store.memory.compressedBytes)) is compressed"

        switch pressureStatus.severity {
        case .normal:
            return "\(usage), with \(compressed). There is comfortable headroom for the current workload."
        case .elevated:
            return "\(usage), with \(compressed). Memory headroom is tighter. Heavier apps or projects may increase compression and reduce responsiveness."
        case .high, .critical:
            return "\(usage), with \(compressed). Memory headroom is low. If responsiveness drops, close memory-heavy apps or reduce the active workload."
        case .unavailable:
            return "Current memory usage is available, but macOS did not provide a memory headroom signal for this sample."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Memory", subtitle: "Unified memory composition and pressure context")

                HStack(alignment: .top, spacing: 16) {
                    Panel(padding: 20, elevated: true, tint: DeckTheme.violet) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 7) {
                                        Text("MEMORY USAGE")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(DeckTheme.secondaryText)
                                        MetricInfoIcon(text: "Used memory is derived from Mach VM counters and is shown against physical unified memory. CPU and GPU share this pool on Apple Silicon.")
                                    }

                                    Text(DeckFormat.percent(store.memory.usagePercent))
                                        .font(.system(size: 46, weight: .medium, design: .monospaced))
                                        .foregroundStyle(DeckTheme.primaryText)
                                        .contentTransition(.numericText())
                                }

                                Spacer()

                                MetricStatusChip(
                                    title: "Pressure",
                                    status: pressureStatus,
                                    value: store.memoryPressure.available
                                        ? "headroom \(DeckFormat.percent(store.memoryPressure.headroomPercent))"
                                        : nil
                                )
                            }

                            DeckUsageBar(value: store.memory.usagePercent, tint: DeckTheme.violet)

                            HStack {
                                Text("\(DeckFormat.bytes(store.memory.usedBytes)) used")
                                Spacer()
                                Text("\(DeckFormat.bytes(store.memory.totalBytes)) physical")
                            }
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DeckTheme.secondaryText)

                            SparklineView(samples: store.memoryHistory, fixedRange: 0...100, tint: DeckTheme.violet)
                                .frame(height: 170)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    DataSurface(padding: 18, tint: DeckTheme.indigo) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 7) {
                                Text("MEMORY COMPOSITION")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(DeckTheme.secondaryText)
                                MetricInfoIcon(text: "Kernel VM page counters for active, wired, compressed, inactive, free, and purgeable memory.")
                            }

                            MemoryCompositionBar(memory: store.memory)

                            MemoryStat(label: "ACTIVE", value: DeckFormat.bytes(store.memory.activeBytes), tint: DeckTheme.accent)
                            MemoryStat(label: "WIRED", value: DeckFormat.bytes(store.memory.wiredBytes), tint: DeckTheme.indigo)
                            MemoryStat(label: "COMPRESSED", value: DeckFormat.bytes(store.memory.compressedBytes), tint: DeckTheme.violet)
                            MemoryStat(label: "INACTIVE", value: DeckFormat.bytes(store.memory.inactiveBytes), tint: DeckTheme.aqua)
                            MemoryStat(label: "FREE", value: DeckFormat.bytes(store.memory.freeBytes), tint: Color.white.opacity(0.45))
                            MemoryStat(label: "PURGEABLE", value: DeckFormat.bytes(store.memory.purgeableBytes), tint: DeckTheme.cyan)
                        }
                    }
                    .frame(width: 330)
                }

                SystemContextCard(
                    title: "Memory pressure",
                    status: pressureStatus.label,
                    headline: pressureHeadline,
                    detail: pressureDetail,
                    note: store.memoryPressure.available
                        ? "Headroom reflects the current macOS memory-pressure sample and compression activity."
                        : nil,
                    symbol: "gauge.with.dots.needle.50percent",
                    tint: pressureStatus.severity.deckTint
                )
            }
            .padding(22)
        }
    }
}

private struct MemoryStat: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(tint).frame(width: 5, height: 5)
                    Text(label)
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(DeckTheme.mutedText)

                Spacer()

                Text(value)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(DeckTheme.primaryText)
            }

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }
}
