import SwiftUI

struct ProcessesView: View {
    @ObservedObject var store: SystemMonitorStore
    @State private var searchText = ""
    @State private var sort: ProcessSort = .cpu
    @State private var selectedPID: Int?

    private var filteredProcesses: [ProcessMetric] {
        var values = store.processes

        if !searchText.isEmpty {
            values = values.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.commandPath.localizedCaseInsensitiveContains(searchText)
                    || String($0.pid).contains(searchText)
            }
        }

        switch sort {
        case .cpu:
            return values.sorted { $0.cpuTotalPercent > $1.cpuTotalPercent }
        case .core:
            return values.sorted { $0.coreUsagePercent > $1.coreUsagePercent }
        case .memory:
            return values.sorted { $0.memoryBytes > $1.memoryBytes }
        case .name:
            return values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .pid:
            return values.sorted { $0.pid < $1.pid }
        }
    }

    private var selectedProcess: ProcessMetric? {
        guard let selectedPID else { return nil }
        return store.processes.first { $0.pid == selectedPID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                SectionHeader(
                    title: "Processes",
                    subtitle: "Read-only process inspection with normalized and per-core CPU context"
                )
                Spacer()
                Text("\(filteredProcesses.count) visible")
                    .font(.system(size: 10))
                    .foregroundStyle(DeckTheme.mutedText)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 14)

            controls
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

            cpuConventionNote
                .padding(.horizontal, 22)
                .padding(.bottom, 12)

            HStack(spacing: 14) {
                processList
                    .frame(maxWidth: .infinity)

                if let selectedProcess {
                    processInspector(selectedProcess)
                        .frame(width: 340)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .task(id: selectedPID) {
            guard let selectedPID else {
                store.clearProcessDetail()
                return
            }
            store.loadProcessDetail(pid: selectedPID)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DeckTheme.mutedText)
                TextField("Search process, command, or PID", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(DeckTheme.primaryText)
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(DeckTheme.dataSurface.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: DeckTheme.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DeckTheme.controlCornerRadius, style: .continuous)
                    .stroke(DeckTheme.border, lineWidth: 1)
            }

            Menu {
                ForEach(ProcessSort.allCases) { option in
                    Button(option.rawValue) { sort = option }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort: \(sort.rawValue)")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DeckTheme.secondaryText)
                .padding(.horizontal, 11)
                .frame(height: 36)
                .background(DeckTheme.dataSurface.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: DeckTheme.controlCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DeckTheme.controlCornerRadius, style: .continuous)
                        .stroke(DeckTheme.border, lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var cpuConventionNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(DeckTheme.accent)

            Text("CPU Total")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DeckTheme.primaryText)
            Text("is the share of the Mac's full logical-CPU capacity (0–100%).")
                .foregroundStyle(DeckTheme.secondaryText)

            Text("Core Usage")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DeckTheme.primaryText)
                .padding(.leading, 6)
            Text("uses the Unix convention where 100% equals one logical CPU and can exceed 100%.")
                .foregroundStyle(DeckTheme.secondaryText)

            Spacer(minLength: 0)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(DeckTheme.dataSurface.opacity(0.58))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DeckTheme.accent.opacity(0.7))
                .frame(width: 2)
        }
    }

    private var processList: some View {
        DataSurface(padding: 0, tint: DeckTheme.indigo) {
            VStack(spacing: 0) {
                ProcessTableHeader()
                DeckDivider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredProcesses) { process in
                            Button {
                                selectedPID = process.pid
                            } label: {
                                ProcessTableRow(process: process, selected: selectedPID == process.pid)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(process.name), PID \(process.pid)")
                            .accessibilityHint("Open process inspector")
                        }
                    }
                }
            }
        }
    }

    private func processInspector(_ process: ProcessMetric) -> some View {
        Panel(padding: 18, elevated: true, tint: DeckTheme.violet) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Process inspector")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DeckTheme.secondaryText)
                    Text(process.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DeckTheme.primaryText)
                        .lineLimit(2)
                }

                DeckDivider()

                InspectorRow(label: "PID", value: String(process.pid))
                InspectorRow(
                    label: "CPU Total",
                    value: String(format: "%.1f%%", process.cpuTotalPercent),
                    help: "Normalized across all logical CPUs. Directly comparable with SystemDeck's 0–100% system CPU value."
                )
                InspectorRow(
                    label: "Core Usage",
                    value: String(format: "%.1f%%", process.coreUsagePercent),
                    help: "Unix process CPU convention: 100% represents one fully utilized logical CPU."
                )
                InspectorRow(label: "Memory", value: DeckFormat.bytes(process.memoryBytes))
                InspectorRow(label: "Runtime", value: process.elapsedTime)

                if let workqueueThreads = process.workqueueThreads {
                    InspectorRow(
                        label: "Workqueue",
                        value: String(workqueueThreads),
                        help: "macOS ps workqueue-thread count; not necessarily the process's total thread count."
                    )
                }

                if store.selectedProcessDetailPID == process.pid {
                    if let detail = store.selectedProcessDetail {
                        InspectorRow(
                            label: "Threads",
                            value: detail.threadCount.map(String.init) ?? "N/A",
                            help: "Loaded on demand for the selected process, not polled continuously."
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Command")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DeckTheme.mutedText)
                            Text(detail.command)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(DeckTheme.secondaryText)
                                .textSelection(.enabled)
                                .lineLimit(5)
                        }
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Loading process detail…")
                                .font(.system(size: 10))
                                .foregroundStyle(DeckTheme.mutedText)
                        }
                    }
                }

                Spacer()

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(DeckTheme.aqua)
                    Text("Process inspection is read-only.")
                        .font(.system(size: 10))
                        .foregroundStyle(DeckTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct ProcessTableHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("PID").frame(width: 58, alignment: .leading)
            Text("PROCESS").frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU TOTAL").frame(width: 82, alignment: .trailing)
            Text("CORE").frame(width: 72, alignment: .trailing)
            Text("MEMORY").frame(width: 92, alignment: .trailing)
            Text("RUNTIME").frame(width: 82, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(DeckTheme.mutedText)
        .padding(.horizontal, 15)
        .frame(height: 36)
    }
}

private struct ProcessTableRow: View {
    let process: ProcessMetric
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text(String(process.pid))
                .frame(width: 58, alignment: .leading)
                .foregroundStyle(DeckTheme.mutedText)

            Text(process.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(DeckTheme.primaryText)
                .lineLimit(1)

            Text(String(format: "%.1f%%", process.cpuTotalPercent))
                .frame(width: 82, alignment: .trailing)
                .foregroundStyle(DeckTheme.cyan)

            Text(String(format: "%.1f%%", process.coreUsagePercent))
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(DeckTheme.secondaryText)

            Text(DeckFormat.bytes(process.memoryBytes))
                .frame(width: 92, alignment: .trailing)
                .foregroundStyle(DeckTheme.secondaryText)

            Text(process.elapsedTime)
                .frame(width: 82, alignment: .trailing)
                .foregroundStyle(DeckTheme.mutedText)
        }
        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
        .padding(.horizontal, 15)
        .frame(height: 39)
        .background {
            if selected {
                HStack(spacing: 0) {
                    Rectangle().fill(DeckTheme.indigo).frame(width: 2)
                    DeckTheme.selectedSurface.opacity(0.55)
                }
            } else if hovering {
                Color.white.opacity(0.028)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .overlay(alignment: .bottom) {
            DeckDivider()
        }
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String
    var help: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 5) {
                Text(label)
                if let help { MetricInfoIcon(text: help) }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(DeckTheme.mutedText)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(DeckTheme.primaryText)
        }
    }
}
