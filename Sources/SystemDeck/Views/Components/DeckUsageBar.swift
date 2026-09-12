import SwiftUI

struct DeckUsageBar: View {
    let value: Double
    var tint: Color = DeckTheme.accent

    private var normalizedValue: Double {
        min(1, max(0, value / 100))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.055))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.62),
                                tint.opacity(0.92)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * normalizedValue)
            }
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage")
        .accessibilityValue("\(Int(value.rounded())) percent")
    }
}
