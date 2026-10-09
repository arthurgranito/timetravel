import Foundation

/// Como o rewind é disparado na tela de bloqueio.
enum RewindTrigger: String, CaseIterable, Identifiable {
    /// Swipe para cima na metade inferior (padrão).
    case swipeUp
    /// Toque duplo no relógio.
    case doubleTapClock
    /// Automático, X segundos depois de acender.
    case automatic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .swipeUp:
            return "Swipe para cima"
        case .doubleTapClock:
            return "Toque duplo no relógio"
        case .automatic:
            return "Automático"
        }
    }
}

/// Efeitos visuais do rewind (os haptics ficam em HapticPreferences).
struct RewindEffects: Equatable {
    /// Deslocamento de 1–2pt e piscada de opacidade no relógio a cada passo.
    var glitch: Bool = false
    /// Zoom lento do wallpaper (1.0 → 1.04) durante o rewind.
    var wallpaperZoom: Bool = true
    /// Cadeado abrindo no início do rewind.
    var padlockOpens: Bool = true
}

/// Preferências de comportamento da mágica usadas pelas views.
/// Na Fase 4 elas passam a vir do AppSettings.
struct MagicPreferences: Equatable {
    var haptics = HapticPreferences()
    /// Ponto cinza-escuro de 3pt num canto por 0,5s a cada toque registrado.
    var showsSecretIndicator: Bool = false
    /// Desenha a grade com os números por cima da tela preta.
    var showsTrainingGrid: Bool = false
    var rewindTrigger: RewindTrigger = .swipeUp
    var autoRewindDelay: TimeInterval = 3
    var effects = RewindEffects()
    /// Impede o bloqueio automático enquanto o app está aberto.
    var keepScreenAwake: Bool = true
    /// Toque longo no estado "live" volta para o preto.
    var liveResetEnabled: Bool = true
    var liveResetDuration: TimeInterval = 1.5
}
