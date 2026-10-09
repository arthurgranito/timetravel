import Foundation

/// Como o tempo de cada minuto do rewind é decidido.
enum RewindPacing: String, CaseIterable, Identifiable, Codable {
    /// Duração total fixa, com curva lenta–rápida–lenta (o modo original).
    case totalDuration
    /// Cada minuto desce num intervalo constante, configurável (padrão).
    case fixedRhythm
    /// Um minuto por segundo, sempre (ritmo travado, fácil de acompanhar falando).
    case stepByStep

    var id: String { rawValue }

    var label: String {
        switch self {
        case .totalDuration:
            return "Duração total"
        case .fixedRhythm:
            return "Ritmo fixo"
        case .stepByStep:
            return "Passo a passo"
        }
    }
}

/// Calcula o timing da animação de "voltar no tempo".
enum RewindPlanner {
    static let defaultDuration: TimeInterval = 3.5
    static let minimumDuration: TimeInterval = 1.2
    /// Ritmo fixo: segundos por minuto (padrão e limites).
    static let defaultSecondsPerMinute: TimeInterval = 1.0
    static let secondsPerMinuteRange: ClosedRange<TimeInterval> = 0.5...5.0
    /// Passo a passo: sempre 1 minuto por segundo.
    static let stepByStepInterval: TimeInterval = 1.0
    /// Profundidade da curva: 0 = intervalos iguais; perto de 1 = meio muito mais rápido que as pontas.
    static let easingDepth: Double = 0.65

    /// Duração efetiva: nunca menor que `minimumDuration`.
    static func effectiveDuration(_ duration: TimeInterval) -> TimeInterval {
        let base = duration.isFinite ? duration : defaultDuration
        return max(base, minimumDuration)
    }

    /// Intervalos (em segundos) antes de cada passo de 1 minuto, para o modo escolhido.
    static func intervals(
        steps: Int,
        pacing: RewindPacing,
        totalDuration: TimeInterval,
        secondsPerMinute: TimeInterval
    ) -> [TimeInterval] {
        switch pacing {
        case .totalDuration:
            return intervals(steps: steps, totalDuration: totalDuration)
        case .fixedRhythm:
            return fixedIntervals(steps: steps, secondsPerMinute: secondsPerMinute)
        case .stepByStep:
            return fixedIntervals(steps: steps, secondsPerMinute: stepByStepInterval)
        }
    }

    /// Ritmo fixo efetivo, sempre dentro de `secondsPerMinuteRange`.
    static func effectiveSecondsPerMinute(_ seconds: TimeInterval) -> TimeInterval {
        let base = seconds.isFinite ? seconds : defaultSecondsPerMinute
        return min(max(base, secondsPerMinuteRange.lowerBound), secondsPerMinuteRange.upperBound)
    }

    /// Intervalos constantes: um minuto a cada `secondsPerMinute` segundos.
    static func fixedIntervals(steps: Int, secondsPerMinute: TimeInterval) -> [TimeInterval] {
        guard steps > 0 else { return [] }
        let interval = effectiveSecondsPerMinute(secondsPerMinute)
        return Array(repeating: interval, count: steps)
    }

    /// Intervalos (em segundos) antes de cada passo de 1 minuto, no modo "Duração total".
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
