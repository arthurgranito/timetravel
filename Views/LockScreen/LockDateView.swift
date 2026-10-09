import SwiftUI

/// Data acima do relógio ("quinta-feira, 8 de outubro").
struct LockDateView: View {
    let text: String
    let style: LockScreenStyle

    var body: some View {
        Text(text)
            .font(.system(size: style.dateSize, weight: style.dateWeight.fontWeight))
            .foregroundStyle(Color.white.opacity(style.dateOpacity))
            .lineLimit(1)
            .fixedSize()
    }
}
