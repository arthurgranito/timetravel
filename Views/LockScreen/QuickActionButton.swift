import SwiftUI

/// Botão circular de lanterna/câmera nos cantos inferiores.
struct QuickActionButton: View {
    let systemImage: String
    let size: CGFloat
    var isActive: Bool = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.4, weight: .regular))
            .foregroundStyle(isActive ? Color.black : Color.white)
            .frame(width: size, height: size)
            .background {
                if isActive {
                    Circle().fill(Color.white)
                } else {
                    Circle().fill(.ultraThinMaterial)
                }
            }
            .environment(\.colorScheme, .dark)
            .contentShape(Circle())
    }
}
