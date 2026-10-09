import SwiftUI

/// Cadeado no topo; abre com um leve bounce (como no desbloqueio por Face ID).
struct PadlockView: View {
    let isOpen: Bool
    let size: CGFloat

    var body: some View {
        Image(systemName: isOpen ? "lock.open.fill" : "lock.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Color.white)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: isOpen)
    }
}
