import SwiftUI

/// Texto discreto "Deslize para cima para abrir" (opcional).
struct UnlockHintView: View {
    var body: some View {
        Text("Deslize para cima para abrir")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color.white.opacity(0.85))
            .lineLimit(1)
            .fixedSize()
    }
}
