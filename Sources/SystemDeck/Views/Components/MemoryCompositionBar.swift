import SwiftUI

struct MemoryCompositionBar: View {
    let memory: MemoryMetric

    private var segments: [(value: UInt64, color: Color)] {
        [
            (memory.activeBytes, DeckTheme.accent),
            (memory.wiredBytes, DeckTheme.indigo),
            (memory.compressedBytes, DeckTheme.violet),
            (memory.inactiveBytes, DeckTheme.aqua),
            (memory.freeBytes, Color.white.opacity(0.16))
        ]
    }

    private var denominator: UInt64 {
        let sum = segments.reduce(UInt64(0)) { partial, segment in
            partial &+ segment.value
        }
        return max(memory.totalBytes, sum)
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    if denominator > 0, segment.value > 0 {
                        Rectangle()
                            .fill(segment.color)
                            .frame(
                                width: max(
                                    1,
                                    proxy.size.width * CGFloat(
                                        min(1, Double(segment.value) / Double(denominator))
                                    )
                                )
                            )
                    }
                }
                Spacer(minLength: 0)
            }
            .clipShape(Capsule())
            .background(Color.white.opacity(0.05), in: Capsule())
        }
        .frame(height: 8)
        .help("Physical-memory composition from kernel VM counters: active, wired, compressed, inactive, and free pages.")
    }
}
