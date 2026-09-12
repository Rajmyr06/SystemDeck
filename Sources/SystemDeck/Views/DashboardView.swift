import SwiftUI

enum DeckSection: String, CaseIterable, Identifiable, Hashable {
    case overview = "Overview"
    case performance = "Performance"
    case processes = "Processes"
    case memory = "Memory"
    case storage = "Storage"
    case network = "Network"
    case battery = "Battery"
    case hardware = "Hardware"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .performance: "waveform.path.ecg"
        case .processes: "list.bullet.rectangle"
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .network: "arrow.up.arrow.down"
        case .battery: "battery.75percent"
        case .hardware: "cpu"
        case .settings: "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .overview: DeckTheme.accent
        case .performance: DeckTheme.accent
        case .processes: DeckTheme.indigo
        case .memory: DeckTheme.violet
        case .storage: DeckTheme.aqua
        case .network: DeckTheme.cyan
        case .battery: DeckTheme.statusNormal
        case .hardware: DeckTheme.indigo
        case .settings: DeckTheme.secondaryText
        }
    }
}

struct DashboardView: View {
    @ObservedObject var store: SystemMonitorStore
    @AppStorage("selectedSection") private var selectedSectionRaw = DeckSection.overview.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selection: DeckSection {
        DeckSection(rawValue: selectedSectionRaw) ?? .overview
    }

    private var selectionBinding: Binding<DeckSection> {
        Binding(
            get: { selection },
            set: { selectedSectionRaw = $0.rawValue }
        )
    }

    var body: some View {
        ZStack {
            DeckBackground()

            HStack(spacing: 0) {
                sidebar
                DeckDivider(vertical: true)
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand

            VStack(spacing: 2) {
                ForEach(DeckSection.allCases) { section in
                    Button {
                        if reduceMotion {
                            selectedSectionRaw = section.rawValue
                        } else {
                            withAnimation(.easeOut(duration: 0.14)) {
                                selectedSectionRaw = section.rawValue
                            }
                        }
                    } label: {
                        sidebarRow(section)
                            .deckRowHover(tint: section.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.rawValue)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            monitoringFooter
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(width: DeckTheme.sidebarWidth)
        .background(.thinMaterial)
        .background(DeckTheme.sidebar.opacity(0.64))
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DeckTheme.accent)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("SystemDeck")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DeckTheme.primaryText)

                Text("System Monitor")
                    .font(.system(size: 10))
                    .foregroundStyle(DeckTheme.mutedText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 18)
    }

    private var monitoringFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            DeckDivider()

            HStack {
                MonitoringIndicator(active: store.isMonitoring)
                Spacer()
                Text(String(format: "%.0fs", store.refreshInterval))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DeckTheme.mutedText)
            }

            Text(store.hardware.computerName)
                .font(.system(size: 10))
                .foregroundStyle(DeckTheme.mutedText)
                .lineLimit(1)
        }
    }

    private func sidebarRow(_ section: DeckSection) -> some View {
        let selected = selection == section

        return HStack(spacing: 10) {
            Rectangle()
                .fill(selected ? section.tint : Color.clear)
                .frame(width: 2, height: 18)
                .clipShape(Capsule())

            Image(systemName: section.symbol)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .frame(width: 17)

            Text(section.rawValue)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))

            Spacer()
        }
        .foregroundStyle(selected ? DeckTheme.primaryText : DeckTheme.secondaryText)
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background {
            RoundedRectangle(cornerRadius: DeckTheme.sidebarSelectionRadius, style: .continuous)
                .fill(selected ? DeckTheme.selectedSurface.opacity(0.68) : Color.clear)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .overview:
            OverviewView(store: store, selection: selectionBinding)
        case .performance:
            PerformanceView(store: store)
        case .processes:
            ProcessesView(store: store)
        case .memory:
            MemoryView(store: store)
        case .storage:
            StorageView(store: store)
        case .network:
            NetworkView(store: store)
        case .battery:
            BatteryView(store: store)
        case .hardware:
            HardwareView(store: store)
        case .settings:
            SettingsView(store: store, embedded: true)
        }
    }
}
