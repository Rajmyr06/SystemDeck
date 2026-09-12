import SwiftUI

enum DeckTheme {
    static let background = Color(red: 5 / 255, green: 8 / 255, blue: 13 / 255)
    static let backgroundLifted = Color(red: 8 / 255, green: 13 / 255, blue: 20 / 255)
    static let sidebar = Color(red: 7 / 255, green: 11 / 255, blue: 17 / 255)
    static let surface = Color(red: 12 / 255, green: 18 / 255, blue: 27 / 255)
    static let dataSurface = Color(red: 10 / 255, green: 16 / 255, blue: 24 / 255)
    static let elevatedSurface = Color(red: 16 / 255, green: 24 / 255, blue: 34 / 255)
    static let selectedSurface = Color(red: 24 / 255, green: 37 / 255, blue: 49 / 255)

    static let border = Color.white.opacity(0.075)
    static let hairline = Color.white.opacity(0.055)

    static let primaryText = Color(red: 231 / 255, green: 238 / 255, blue: 244 / 255)
    static let secondaryText = Color(red: 157 / 255, green: 174 / 255, blue: 188 / 255)
    static let mutedText = Color(red: 104 / 255, green: 121 / 255, blue: 135 / 255)

    static let accent = Color(red: 126 / 255, green: 184 / 255, blue: 226 / 255)
    static let cyan = Color(red: 91 / 255, green: 207 / 255, blue: 221 / 255)
    static let violet = Color(red: 158 / 255, green: 139 / 255, blue: 224 / 255)
    static let indigo = Color(red: 105 / 255, green: 137 / 255, blue: 219 / 255)
    static let aqua = Color(red: 102 / 255, green: 191 / 255, blue: 189 / 255)

    static let statusNormal = Color(red: 112 / 255, green: 186 / 255, blue: 176 / 255)
    static let statusElevated = Color(red: 214 / 255, green: 174 / 255, blue: 99 / 255)
    static let statusHigh = Color(red: 220 / 255, green: 139 / 255, blue: 82 / 255)
    static let statusCritical = Color(red: 214 / 255, green: 93 / 255, blue: 101 / 255)
    static let statusUnavailable = mutedText

    static let panelCornerRadius: CGFloat = 12
    static let controlCornerRadius: CGFloat = 8
    static let sidebarSelectionRadius: CGFloat = 7
    static let sidebarWidth: CGFloat = 196

    static let glassBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.14),
            accent.opacity(0.07),
            Color.white.opacity(0.035)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

}

extension MetricSeverity {
    var deckTint: Color {
        switch self {
        case .normal: DeckTheme.statusNormal
        case .elevated: DeckTheme.statusElevated
        case .high: DeckTheme.statusHigh
        case .critical: DeckTheme.statusCritical
        case .unavailable: DeckTheme.statusUnavailable
        }
    }
}
