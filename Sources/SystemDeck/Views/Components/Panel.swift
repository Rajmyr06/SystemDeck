import SwiftUI

struct Panel<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var elevated = false
    var tint: Color = DeckTheme.accent

    @AppStorage("glassIntensity") private var glassIntensity = 0.28
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        padding: CGFloat = 16,
        elevated: Bool = false,
        tint: Color = DeckTheme.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.elevated = elevated
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background { glassSurface }
            .clipShape(shape)
            .overlay { shape.stroke(DeckTheme.glassBorder, lineWidth: 1) }
            .shadow(
                color: tint.opacity(elevated ? 0.20 + glassIntensity * 0.10 : 0.08 + glassIntensity * 0.06),
                radius: elevated ? 18 : 10,
                x: 0,
                y: elevated ? 8 : 4
            )
            .shadow(
                color: Color.black.opacity(elevated ? 0.16 : 0.08),
                radius: elevated ? 20 : 8,
                x: 0,
                y: elevated ? 12 : 4
            )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DeckTheme.panelCornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var glassSurface: some View {
        if reduceTransparency {
            shape.fill(elevated ? DeckTheme.elevatedSurface : DeckTheme.surface)
        } else {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04 + glassIntensity * 0.10),
                            tint.opacity(glassIntensity * (elevated ? 0.55 : 0.34)),
                            DeckTheme.surface.opacity(elevated ? 0.62 : 0.56),
                            Color.black.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                shape.fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(glassIntensity * 0.28),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 180
                    )
                )
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14 + glassIntensity * 0.10),
                            Color.white.opacity(0.01)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .blendMode(.screen)
                )
            }
        }
    }
}

struct DataSurface<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var tint: Color = DeckTheme.accent

    @AppStorage("glassIntensity") private var glassIntensity = 0.28
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        padding: CGFloat = 16,
        tint: Color = DeckTheme.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(reduceTransparency ? DeckTheme.dataSurface : DeckTheme.dataSurface.opacity(0.70))
                    .background {
                        if !reduceTransparency {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .overlay {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.03 + glassIntensity * 0.08),
                                    Color.clear,
                                    tint.opacity(glassIntensity * 0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            RadialGradient(
                                colors: [
                                    tint.opacity(glassIntensity * 0.18),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 140
                            )
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DeckTheme.border.opacity(0.95), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.05 + glassIntensity * 0.08), radius: 8, x: 0, y: 4)
    }
}

struct DeckDivider: View {
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(DeckTheme.hairline)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

struct MonitoringIndicator: View {
    let active: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? DeckTheme.statusNormal : DeckTheme.statusUnavailable)
                .frame(width: 6, height: 6)
            Text(active ? "Live" : "Paused")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(active ? DeckTheme.primaryText : DeckTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(active ? "Monitoring live" : "Monitoring paused")
    }
}


extension View {
    func deckInteractive(tint: Color = DeckTheme.accent) -> some View {
        modifier(DeckInteractiveSurfaceModifier(tint: tint))
    }

    func deckRowHover(tint: Color = DeckTheme.accent) -> some View {
        modifier(DeckInteractiveRowModifier(tint: tint))
    }
}


private struct DeckInteractiveSurfaceModifier: ViewModifier {
    let tint: Color
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: DeckTheme.panelCornerRadius, style: .continuous)
                    .stroke(
                        hovering ? tint.opacity(0.26) : Color.clear,
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .background {
                RoundedRectangle(cornerRadius: DeckTheme.panelCornerRadius, style: .continuous)
                    .fill(hovering ? tint.opacity(0.025) : Color.clear)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: hovering ? tint.opacity(0.10) : Color.clear,
                radius: hovering ? 10 : 0,
                x: 0,
                y: 4
            )
            .scaleEffect(hovering && !reduceMotion ? 1.0015 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: hovering)
            .onHover { hovering = $0 }
    }
}

private struct DeckInteractiveRowModifier: ViewModifier {
    let tint: Color
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(hovering ? tint.opacity(0.045) : Color.clear)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(hovering ? tint.opacity(0.70) : Color.clear)
                    .frame(width: 2)
                    .allowsHitTesting(false)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.11), value: hovering)
            .onHover { hovering = $0 }
    }
}
