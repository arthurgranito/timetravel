import UIKit

/// Guarda e restaura o brilho da tela.
@MainActor
final class ScreenBrightness {
    private var saved: CGFloat?

    /// Ao entrar na tela preta: lembra o brilho atual.
    func save() {
        saved = currentScreen.brightness
    }

    /// Ao acordar a tela de bloqueio: garante o brilho salvo.
    func applySaved() {
        guard let saved, abs(currentScreen.brightness - saved) > 0.01 else { return }
        currentScreen.brightness = saved
    }

    /// Ao sair do app: devolve o brilho original.
    func restore() {
        applySaved()
    }

    private var currentScreen: UIScreen {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first?.screen ?? UIScreen.main
    }
}
