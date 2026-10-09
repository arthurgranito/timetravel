import Foundation

/// Como o rewind é disparado na tela de bloqueio.
enum RewindTrigger: String, CaseIterable, Identifiable, Codable {
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

// MARK: - Codable tolerante (campos ausentes usam o padrão)

extension MagicPreferences: Codable {
    enum CodingKeys: String, CodingKey {
        case haptics, showsSecretIndicator, showsTrainingGrid, rewindTrigger, autoRewindDelay, effects
        case keepScreenAwake, liveResetEnabled, liveResetDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = MagicPreferences()
        self.init()
        haptics = container.value(.haptics, default: fallback.haptics)
        showsSecretIndicator = container.value(.showsSecretIndicator, default: fallback.showsSecretIndicator)
        showsTrainingGrid = container.value(.showsTrainingGrid, default: fallback.showsTrainingGrid)
        rewindTrigger = container.value(.rewindTrigger, default: fallback.rewindTrigger)
        autoRewindDelay = container.value(.autoRewindDelay, default: fallback.autoRewindDelay)
        effects = container.value(.effects, default: fallback.effects)
        keepScreenAwake = container.value(.keepScreenAwake, default: fallback.keepScreenAwake)
        liveResetEnabled = container.value(.liveResetEnabled, default: fallback.liveResetEnabled)
        liveResetDuration = container.value(.liveResetDuration, default: fallback.liveResetDuration)
    }
}

extension RewindEffects: Codable {
    enum CodingKeys: String, CodingKey {
        case glitch, wallpaperZoom, padlockOpens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = RewindEffects()
        self.init()
        glitch = container.value(.glitch, default: fallback.glitch)
        wallpaperZoom = container.value(.wallpaperZoom, default: fallback.wallpaperZoom)
        padlockOpens = container.value(.padlockOpens, default: fallback.padlockOpens)
    }
}
