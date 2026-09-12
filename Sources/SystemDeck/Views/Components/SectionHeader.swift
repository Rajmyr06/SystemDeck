import SwiftUI

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DeckTheme.primaryText)

            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DeckTheme.secondaryText)
        }
    }
}
