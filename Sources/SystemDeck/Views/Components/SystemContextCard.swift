import SwiftUI

struct SystemContextCard: View {
    let title: String
    let status: String?
    let headline: String
    let detail: String
    let note: String?
    let symbol: String
    let tint: Color

    init(
        title: String,
        status: String? = nil,
        headline: String,
        detail: String,
        note: String? = nil,
        symbol: String,
        tint: Color
    ) {
        self.title = title
        self.status = status
        self.headline = headline
        self.detail = detail
        self.note = note
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        DataSurface(padding: 18, tint: tint) {
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DeckTheme.primaryText)

                        if let status {
                            Text(status)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(tint)
                        }

                        Spacer(minLength: 0)
                    }

                    Text(headline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DeckTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(DeckTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 10.5))
                            .foregroundStyle(DeckTheme.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }
                }
            }
        }
    }
}
