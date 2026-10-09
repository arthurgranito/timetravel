import Foundation

/// Calcula o timing da animação de "voltar no tempo".
enum RewindPlanner {
    static let defaultDuration: TimeInterval = 3.5
    static let minimumDuration: TimeInterval = 1.2
    /// Profundidade da curva: 0 = intervalos iguais; perto de 1 = meio muito mais rápido que as pontas.
    static let easingDepth: Double = 0.65

    /// Duração efetiva: nunca menor que `minimumDuration`.
    static func effectiveDuration(_ duration: TimeInterval) -> TimeInterval {
        let base = duration.isFinite ? duration : defaultDuration
        return max(base, minimumDuration)
    }

    /// Intervalos (em segundos) antes de cada passo de 1 minuto.
    /// Começa devagar, acelera no meio e desacelera no fim. A soma é a duração efetiva.
    static func intervals(steps: Int, totalDuration: TimeInterval) -> [TimeInterval] {
        guard steps > 0 else { return [] }
        let total = effectiveDuration(totalDuration)
        let weights: [Double] = (0..<steps).map { index in
            let position = (Double(index) + 0.5) / Double(steps)
            return 1.0 - easingDepth * sin(Double.pi * position)
        }
        let sum = weights.reduce(0, +)
        return weights.map { $0 / sum * total }
    }
}

/// Progresso de uma animação de rewind em andamento (lógica pura).
///
/// O alvo é dinâmico: a cada passo o minuto mostrado desce 1, mas nunca fica abaixo
/// da hora real *naquele instante*. Assim, se o minuto real virar durante a animação,
/// ela simplesmente termina um passo antes, exatamente na hora real, sem repetir valores.
struct RewindProgress: Equatable {
    let initialOffset: Int
    let intervals: [TimeInterval]
    private(set) var shownMinute: Date
    private(set) var completedSteps: Int = 0
    private(set) var isFinished: Bool = false

    init(startedAt now: Date, offsetMinutes: Int, intervals: [TimeInterval], calendar: Calendar) {
        self.initialOffset = offsetMinutes
        self.intervals = intervals
        self.shownMinute = TimeEngine.displayedMinute(now: now, offsetMinutes: offsetMinutes, calendar: calendar)
        let real = TimeEngine.truncatedToMinute(now, calendar: calendar)
        if shownMinute <= real || intervals.isEmpty {
            shownMinute = real
            isFinished = true
        }
    }

    /// Intervalo de espera antes do próximo passo, ou nil se terminou.
    var nextInterval: TimeInterval? {
        guard !isFinished, completedSteps < intervals.count else { return nil }
        return intervals[completedSteps]
    }

    /// Executa um passo usando a hora real `now`.
    mutating func advance(now: Date, calendar: Calendar) {
        guard !isFinished else { return }
        let real = TimeEngine.truncatedToMinute(now, calendar: calendar)
        completedSteps += 1
        let candidate = shownMinute.addingTimeInterval(-60)
        shownMinute = max(candidate, real)
        if shownMinute <= real || completedSteps >= intervals.count {
            // Termina sempre exatamente na hora real.
            shownMinute = real
            isFinished = true
        }
    }
}
