import SwiftUI

struct CoreCPUGrid: View {
    let cores: [CoreCPUMetric]

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 110), spacing: 14),
        count: 4
    )

    var body: some View {
        DataSurface(padding: 16, tint: DeckTheme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Per-core CPU")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DeckTheme.primaryText)
                    Spacer()
                    Text("\(cores.count) logical CPUs")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(DeckTheme.mutedText)
                }

                if cores.isEmpty {
                    Text("Waiting for per-core samples…")
                        .font(.system(size: 11))
                        .foregroundStyle(DeckTheme.mutedText)
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(cores) { core in
                            CoreCPUItem(core: core)
                        }
                    }
                }
            }
        }
    }
}

private struct CoreCPUItem: View {
    let core: CoreCPUMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(core.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DeckTheme.secondaryText)
                Spacer()
                Text(DeckFormat.percent(core.usagePercent))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DeckTheme.primaryText)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DeckTheme.hairline)
                    Capsule()
                        .fill(DeckTheme.accent.opacity(0.78))
                        .frame(width: proxy.size.width * max(0, min(1, core.usagePercent / 100)))
                }
            }
            .frame(height: 5)
        }
    }
}
