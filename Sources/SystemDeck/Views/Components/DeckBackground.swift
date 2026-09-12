import SwiftUI

struct DeckBackground: View {
    @AppStorage("glassIntensity") private var glassIntensity = 0.16
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DeckTheme.background, DeckTheme.backgroundLifted, DeckTheme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if !reduceTransparency {
                glow(color: DeckTheme.accent, size: 620, opacity: glassIntensity * 0.26, x: -470, y: -330)
                glow(color: DeckTheme.indigo, size: 520, opacity: glassIntensity * 0.14, x: 500, y: 390)
            }

            LinearGradient(
                colors: [Color.white.opacity(0.010), Color.clear, Color.black.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func glow(color: Color, size: CGFloat, opacity: Double, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity), color.opacity(opacity * 0.24), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 54)
            .offset(x: x, y: y)
    }
}
