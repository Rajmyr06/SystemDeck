import Charts
import SwiftUI

struct SparklineView: View {
    let samples: [MetricSample]
    var fixedRange: ClosedRange<Double>? = nil
    var tint: Color = DeckTheme.accent

    var body: some View {
        Chart(samples) { sample in
            AreaMark(
                x: .value("Time", sample.timestamp),
                y: .value("Value", sample.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        tint.opacity(0.30),
                        tint.opacity(0.055),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", sample.timestamp),
                y: .value("Value", sample.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round))
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.75), tint],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .modifier(OptionalYScale(range: fixedRange))
    }
}

private struct OptionalYScale: ViewModifier {
    let range: ClosedRange<Double>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let range {
            content.chartYScale(domain: range)
        } else {
            content
        }
    }
}
