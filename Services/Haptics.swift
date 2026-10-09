import UIKit

/// Como a entrada secreta confirma o número pelo tato.
enum SecretHapticMode: String, CaseIterable, Identifiable, Codable {
    case none
    case light
    /// N batidas leves (no modo C: dezena e depois unidade; 0 = uma batida rígida).
    case perDigit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:
            return "Nenhum"
        case .light:
            return "Leve"
        case .perDigit:
            return "Uma batida por unidade"
        }
    }
}

struct HapticPreferences: Equatable {
    var secretMode: SecretHapticMode = .light
    /// Modo B: batida sutil a cada toque contado.
    var tapCountTicks: Bool = true
    /// Batida leve a cada minuto durante o rewind.
    var rewindSteps: Bool = true
    /// Batida de "sucesso" ao terminar o rewind.
    var rewindFinish: Bool = true
}

/// Traduz eventos da mágica em haptics.
@MainActor
final class Haptics {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private var patternTask: Task<Void, Never>?

    func prepare() {
        lightImpact.prepare()
        softImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
    }

    func handle(_ feedback: TrickFeedback, preferences: HapticPreferences) {
        switch feedback {
        case .inputTap:
            guard preferences.tapCountTicks, preferences.secretMode != .none else { return }
            softImpact.impactOccurred(intensity: 0.6)
            softImpact.prepare()
        case let .digitRegistered(digit):
            secret(digit, preferences: preferences)
        case let .armed(value):
            secret(value, preferences: preferences)
        case .error:
            guard preferences.secretMode != .none else { return }
            notification.notificationOccurred(.error)
        case .reset:
            guard preferences.secretMode != .none else { return }
            rigidImpact.impactOccurred(intensity: 0.7)
        case .wake:
            prepare()
        case .rewindStep:
            guard preferences.rewindSteps else { return }
            lightImpact.impactOccurred(intensity: 0.7)
            lightImpact.prepare()
        case .rewindFinished:
            guard preferences.rewindFinish else { return }
            notification.notificationOccurred(.success)
        }
    }

    /// Batida simples (botões da tela de bloqueio).
    func tap() {
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }

    private func secret(_ value: Int, preferences: HapticPreferences) {
        switch preferences.secretMode {
        case .none:
            return
        case .light:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .perDigit:
            pulses(value % 10)
        }
    }

    /// N batidas leves espaçadas; 0 vira uma batida rígida.
    private func pulses(_ count: Int) {
        patternTask?.cancel()
        guard count > 0 else {
            rigidImpact.impactOccurred()
            return
        }
        patternTask = Task { [weak self] in
            for index in 0..<count {
                if Task.isCancelled { return }
                self?.lightImpact.impactOccurred()
                self?.lightImpact.prepare()
                if index < count - 1 {
                    try? await Task.sleep(nanoseconds: 160_000_000)
                }
            }
        }
    }
}

// MARK: - Codable tolerante (campos ausentes usam o padrão)

extension HapticPreferences: Codable {
    enum CodingKeys: String, CodingKey {
        case secretMode, tapCountTicks, rewindSteps, rewindFinish
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = HapticPreferences()
        self.init()
        secretMode = container.value(.secretMode, default: fallback.secretMode)
        tapCountTicks = container.value(.tapCountTicks, default: fallback.tapCountTicks)
        rewindSteps = container.value(.rewindSteps, default: fallback.rewindSteps)
        rewindFinish = container.value(.rewindFinish, default: fallback.rewindFinish)
    }
}
