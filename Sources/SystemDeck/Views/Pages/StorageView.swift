import SwiftUI

struct StorageView: View {
    @ObservedObject var store: SystemMonitorStore

    private var storageStatus: MetricStatus {
        MetricStatusEvaluator.disk(
            usagePercent: store.disk.usagePercent,
            totalBytes: store.disk.totalBytes
        )
    }

    private var capacityHeadline: String {
        guard store.disk.totalBytes > 0 else { return "Storage capacity is unavailable" }
        return "\(DeckFormat.percent(store.disk.usagePercent)) used · \(DeckFormat.bytes(store.disk.freeBytes)) free"
    }

    private var capacityDetail: String {
        guard store.disk.totalBytes > 0 else { return "SystemDeck could not read the capacity of the monitored filesystem." }

        switch storageStatus.severity {
        case .normal:
            return "Capacity is within the normal range. There is currently enough free space for routine app, cache, and update activity."
        case .elevated:
            return "Free space is getting limited. Plan a cleanup before usage reaches 90% so macOS and large apps retain working room."
        case .high, .critical:
            return "Storage is nearly full. Freeing space now is recommended to leave room for updates, caches, and temporary files."
        case .unavailable:
            return "Storage usage is not available right now."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Storage", subtitle: "Internal filesystem capacity")

                Panel(padding: 20, elevated: true, tint: storageStatus.severity.deckTint) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 7) {
                                    Text("INTERNAL STORAGE")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .tracking(0.8)
                                        .foregroundStyle(DeckTheme.secondaryText)

                                    MetricInfoIcon(
                                        text: "Filesystem capacity for the volume containing your home directory. This is capacity usage, not disk read/write throughput."
                                    )
                                }

                                Text(store.disk.totalBytes > 0 ? DeckFormat.bytes(store.disk.totalBytes) : "N/A")
                                    .font(.system(size: 38, weight: .medium, design: .monospaced))
                                    .foregroundStyle(DeckTheme.primaryText)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 8) {
                                Text(store.disk.totalBytes > 0 ? DeckFormat.percent(store.disk.usagePercent) : "N/A")
                                    .font(.system(size: 31, weight: .medium, design: .monospaced))
                                    .foregroundStyle(storageStatus.severity.deckTint)

                                MetricStatusChip(
                                    title: "Capacity",
                                    status: storageStatus
                                )
                            }
                        }

                        DeckUsageBar(value: store.disk.usagePercent, tint: storageStatus.severity.deckTint)
                            .frame(height: 8)

                        HStack(spacing: 12) {
                            StoragePill(label: "USED", value: store.disk.totalBytes > 0 ? DeckFormat.bytes(store.disk.usedBytes) : "N/A", tint: DeckTheme.aqua)
                            StoragePill(label: "FREE", value: store.disk.totalBytes > 0 ? DeckFormat.bytes(store.disk.freeBytes) : "N/A", tint: DeckTheme.cyan)
                            StoragePill(label: "TOTAL", value: store.disk.totalBytes > 0 ? DeckFormat.bytes(store.disk.totalBytes) : "N/A", tint: DeckTheme.indigo)
                            Spacer()
                        }
                    }
                }

                SystemContextCard(
                    title: "Storage capacity",
                    status: storageStatus.label,
                    headline: capacityHeadline,
                    detail: capacityDetail,
                    note: "Capacity bands: below 80% normal · 80–90% elevated · above 90% high.",
                    symbol: "internaldrive.fill",
                    tint: storageStatus.severity.deckTint
                )

            }
            .padding(22)
        }
    }
}

private struct StoragePill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(label).foregroundStyle(DeckTheme.mutedText)
            Text(value).foregroundStyle(DeckTheme.primaryText)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(.ultraThinMaterial)
        .background(tint.opacity(0.08))
        .clipShape(Capsule())
        .overlay { Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1) }
    }
}
