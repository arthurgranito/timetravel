import Foundation
import Observation
import os

/// Chaves do UserDefaults, todas num lugar só.
enum SettingsKey: String {
    /// Todas as configurações, como JSON (AppSettingsData).
    case settingsData = "settings.v1"
}

/// Gesto secreto que abre as configurações (só a partir da tela preta).
enum SettingsGesture: String, CaseIterable, Identifiable, Codable {
    /// Três toques com dois dedos em menos de 1,5s (padrão).
    case threeTwoFingerTaps
    /// Toque longo de 3s no canto superior esquerdo.
    case cornerLongPress

    var id: String { rawValue }

    var label: String {
        switch self {
        case .threeTwoFingerTaps:
            return "3 toques com 2 dedos"
        case .cornerLongPress:
            return "Segurar 3s no canto superior esquerdo"
        }
    }
}

/// Todas as configurações do app, com os valores padrão definidos aqui e nos structs aninhados.
struct AppSettingsData: Equatable {
    var style = LockScreenStyle()
    var preferences = MagicPreferences()
    var inputMode: SecretInputMode = .grid
    /// Inatividade (s) que zera uma entrada parcial nos modos B e C.
    var inputTimeout: TimeInterval = 5
    var rewindDuration: TimeInterval = RewindPlanner.defaultDuration
    var returnToDarkOnBackground: Bool = true
    var settingsGesture: SettingsGesture = .threeTwoFingerTaps

    /// Configuração do núcleo derivada das configurações.
    var trickConfiguration: TrickConfiguration {
        var configuration = TrickConfiguration()
        configuration.inputMode = inputMode
        configuration.inputTimeout = inputTimeout
        configuration.rewindDuration = rewindDuration
        configuration.autoRewindDelay = preferences.rewindTrigger == .automatic ? preferences.autoRewindDelay : nil
        configuration.returnToDarkOnBackground = returnToDarkOnBackground
        return configuration
    }
}

/// Configurações persistidas no UserDefaults (as imagens ficam no WallpaperStore).
@MainActor
@Observable
final class AppSettings {
    var data: AppSettingsData

    private let defaults: UserDefaults
    private static let logger = Logger(subsystem: AppLog.subsystem, category: "Settings")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.data(forKey: SettingsKey.settingsData.rawValue),
           let decoded = try? JSONDecoder().decode(AppSettingsData.self, from: raw) {
            data = decoded
        } else {
            data = AppSettingsData()
        }
    }

    func save() {
        do {
            let raw = try JSONEncoder().encode(data)
            defaults.set(raw, forKey: SettingsKey.settingsData.rawValue)
        } catch {
            AppSettings.logger.error("Falha ao salvar configurações")
        }
    }

    func resetAll() {
        data = AppSettingsData()
        save()
    }
}

// MARK: - Codable tolerante
// Cada campo que faltar no JSON salvo (ex.: depois de uma atualização do app) usa o valor padrão,
// em vez de perder todas as configurações.

extension AppSettingsData: Codable {
    enum CodingKeys: String, CodingKey {
        case style, preferences, inputMode, inputTimeout, rewindDuration, returnToDarkOnBackground, settingsGesture
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettingsData()
        self.init()
        style = container.value(.style, default: fallback.style)
        preferences = container.value(.preferences, default: fallback.preferences)
        inputMode = container.value(.inputMode, default: fallback.inputMode)
        inputTimeout = container.value(.inputTimeout, default: fallback.inputTimeout)
        rewindDuration = container.value(.rewindDuration, default: fallback.rewindDuration)
        returnToDarkOnBackground = container.value(.returnToDarkOnBackground, default: fallback.returnToDarkOnBackground)
        settingsGesture = container.value(.settingsGesture, default: fallback.settingsGesture)
    }
}

