import Charts
import SwiftUI

enum PerformanceAxisKind {
    case percentage
    case rate
    case plain
}

struct PerformanceChart: View {
    let title: String
    let value: String
    let samples: [MetricSample]
    var fixedRange: ClosedRange<Double>? = nil
    var tint: Color = DeckTheme.accent
    var axisKind: PerformanceAxisKind = .plain
    var help: String? = nil

    var body: some View {
        DataSurface(padding: 16, tint: tint) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DeckTheme.secondaryText)

                        if let help {
                            MetricInfoIcon(text: help)
                        }
                    }

                    Spacer()

                    Text(value)
                        .font(.system(size: 23, weight: .medium, design: .monospaced))
                        .foregroundStyle(DeckTheme.primaryText)
                        .contentTransition(.numericText())
                }

                Chart(samples) { sample in
                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Value", sample.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.16), tint.opacity(0.025), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Value", sample.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))
                }
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(DeckTheme.hairline)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(DeckTheme.hairline)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(axisLabel(for: number))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(DeckTheme.mutedText)
                            }
                        }
                    }
                }
                .modifier(PerformanceOptionalYScale(range: fixedRange))
                .frame(minHeight: 172)

                HStack {
                    Text(samples.isEmpty ? "Waiting for samples" : "Older")
                    Spacer()
                    Text("Now")
                }
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(DeckTheme.mutedText)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func axisLabel(for value: Double) -> String {
        switch axisKind {
        case .percentage:
            return String(format: "%.0f%%", value)
        case .rate:
            return DeckFormat.rate(value)
        case .plain:
            return String(format: "%.0f", value)
        }
    }
}

private struct PerformanceOptionalYScale: ViewModifier {
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
