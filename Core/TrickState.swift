import Foundation

/// Máquina de estados da mágica. Só o TrickController faz transições.
enum TrickState: Equatable {
    /// Tela preta aguardando a entrada secreta (o buffer fica no SecretInput do controller).
    case dark
    /// Ainda preto, número guardado.
    case armed(offset: Int)
    /// Tela de bloqueio mostrando real + offset.
    case lockScreen(offset: Int)
    /// Animação voltando no tempo.
    case rewinding(from: Int)
    /// Tela de bloqueio sincronizada com a hora real, para sempre.
    case live
    /// Configurações (só acessível a partir do dark).
    case settings

    /// Estados em que a tela é preta.
    var isDark: Bool {
        switch self {
        case .dark, .armed:
            return true
        default:
            return false
        }
    }

    /// Estados em que a tela de bloqueio falsa aparece.
    var showsLockScreen: Bool {
        switch self {
        case .lockScreen, .rewinding, .live:
            return true
        default:
            return false
        }
    }
}
