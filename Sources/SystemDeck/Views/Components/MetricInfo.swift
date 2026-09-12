import SwiftUI

struct MetricInfoIcon: View {
    let text: String

    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(DeckTheme.mutedText)
            .help(text)
            .accessibilityLabel("Metric information")
            .accessibilityHint(text)
    }
}

struct MetricStatusChip: View {
    let title: String
    let status: MetricStatus
    var value: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(status.severity.deckTint)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DeckTheme.primaryText)

            Text(status.label)
                .font(.system(size: 10))
                .foregroundStyle(DeckTheme.secondaryText)

            if let value {
                Text(value)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(DeckTheme.mutedText)
            }
        }
        .help(status.explanation)
    }

    private var symbol: String {
        switch status.severity {
        case .normal: "checkmark.circle.fill"
        case .elevated: "exclamationmark.circle.fill"
        case .high, .critical: "exclamationmark.triangle.fill"
        case .unavailable: "questionmark.circle"
        }
    }
}
