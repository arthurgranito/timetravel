import Foundation
import CoreGraphics
import Observation
import os

/// Eventos de feedback (haptics etc.) emitidos pelo controller.
/// Quem decide se/como tocar o haptic é a camada de serviços.
enum TrickFeedback: Equatable {
    case inputTap(count: Int)
    case digitRegistered(Int)
    case armed(Int)
    case error
    case reset
    case wake
    case rewindStep
    case rewindFinished
}

/// Parâmetros que influenciam o comportamento da mágica.
/// Na Fase 4 eles passam a vir das configurações (AppSettings).
struct TrickConfiguration: Equatable {
    var inputMode: SecretInputMode = .grid
    /// Inatividade (s) que zera uma entrada parcial (modos B e C). 0 = desligado.
    var inputTimeout: TimeInterval = 5
    var gridVerticalMargin: CGFloat = SecretGridLayout.defaultVerticalMargin
    var rewindDuration: TimeInterval = RewindPlanner.defaultDuration
    /// Dispara o rewind sozinho X segundos depois de acender. nil = desligado.
    var autoRewindDelay: TimeInterval? = nil
    /// Volta para o preto quando o app vai para o background.
    var returnToDarkOnBackground: Bool = true
}

/// Orquestra a mágica. Todas as transições de estado passam por aqui.
@MainActor
@Observable
final class TrickController {
    private(set) var state: TrickState = .dark
    private(set) var secretInput: SecretInput
    private(set) var rewindProgress: RewindProgress?
    private(set) var configuration: TrickConfiguration
    /// Incrementa a cada toque registrado pela entrada secreta (para o indicador visual discreto).
    private(set) var inputFeedbackCount: Int = 0

    @ObservationIgnored var onFeedback: (@MainActor (TrickFeedback) -> Void)?
    let calendar: Calendar
    /// Hora congelada (só nos estados de demonstração usados pelos screenshots da CI).
    let frozenNow: Date?
    private let nowProvider: () -> Date
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var rewindTask: Task<Void, Never>?
    @ObservationIgnored private var autoRewindTask: Task<Void, Never>?

    init(
        configuration: TrickConfiguration = TrickConfiguration(),
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = { Date() },
        frozenNow: Date? = nil
    ) {
        self.configuration = configuration
        self.calendar = calendar
        self.frozenNow = frozenNow
        self.nowProvider = now
        self.secretInput = SecretInput(mode: configuration.inputMode, verticalMargin: configuration.gridVerticalMargin)
    }

    // MARK: - Leitura

    /// Offset (minutos) atualmente guardado/exibido, se houver.
    var currentOffset: Int? {
        switch state {
        case let .armed(offset), let .lockScreen(offset), let .rewinding(offset):
            return offset
        case .dark, .live, .settings:
            return nil
        }
    }

    /// Minuto que o relógio falso deve mostrar para a hora real `now`.
    func displayedMinute(now: Date) -> Date {
        switch state {
        case let .lockScreen(offset):
            return TimeEngine.displayedMinute(now: now, offsetMinutes: offset, calendar: calendar)
        case .rewinding:
            return rewindProgress?.shownMinute ?? TimeEngine.truncatedToMinute(now, calendar: calendar)
        case .dark, .armed, .live, .settings:
            return TimeEngine.truncatedToMinute(now, calendar: calendar)
        }
    }

    /// Hora real a usar num redesenho do relógio: a do TimelineView ou a atual, a que for mais nova
    /// (nunca uma data atrasada), ou a hora congelada da demonstração.
    func clockDate(timelineDate: Date) -> Date {
        if let frozenNow {
            return frozenNow
        }
        return max(timelineDate, nowProvider())
    }

    /// Layout da grade para o modo atual (usado pelo modo treino).
    func gridLayout(for canvas: InputCanvas) -> SecretGridLayout {
        SecretGridLayout(mode: configuration.inputMode, canvas: canvas, verticalMargin: configuration.gridVerticalMargin)
    }

    // MARK: - Configuração

    func updateConfiguration(_ newValue: TrickConfiguration) {
        let modeChanged = newValue.inputMode != configuration.inputMode
        configuration = newValue
        secretInput.verticalMargin = newValue.gridVerticalMargin
        if modeChanged {
            secretInput.setMode(newValue.inputMode)
            cancelTimeout()
            if case .armed = state {
                state = .dark
            }
        }
    }

    // MARK: - Entrada secreta (só na tela preta)

    func handleTap(at point: CGPoint, in canvas: InputCanvas) {
        guard state.isDark else { return }
        apply(secretInput.handle(.tap(at: point, canvas: canvas)))
    }

    func handleLongPress() {
        guard state.isDark else { return }
        apply(secretInput.handle(.longPress))
    }

    func handleInputTimeout() {
        guard state.isDark else { return }
        apply(secretInput.handle(.timeout))
    }

    /// Gesto de reset (dois dedos na tela preta, ou long press no live).
    func handleResetGesture() {
        guard state.isDark || state == .live else { return }
        resetToDark()
        emit(.reset)
    }

    // MARK: - Rewind

    func triggerRewind() {
        guard case let .lockScreen(offset) = state else { return }
        cancelAutoRewind()
        let now = nowProvider()
        let intervals = RewindPlanner.intervals(steps: offset, totalDuration: configuration.rewindDuration)
        let progress = RewindProgress(startedAt: now, offsetMinutes: offset, intervals: intervals, calendar: calendar)
        rewindProgress = progress
        state = .rewinding(from: offset)
        AppLog.rewind.debug("Rewind iniciado: \(offset, privacy: .public) min")
        if progress.isFinished {
            finishRewind()
            return
        }
        rewindTask?.cancel()
        rewindTask = Task { [weak self] in
            await self?.runRewindLoop()
        }
    }

    private func runRewindLoop() async {
        while let interval = rewindProgress?.nextInterval {
            try? await Task.sleep(nanoseconds: TrickController.nanoseconds(interval))
            if Task.isCancelled { return }
            guard case .rewinding = state, var progress = rewindProgress else { return }
            progress.advance(now: nowProvider(), calendar: calendar)
            rewindProgress = progress
            if progress.isFinished {
                break
            }
            emit(.rewindStep)
        }
        if Task.isCancelled { return }
        guard case .rewinding = state else { return }
        finishRewind()
    }

    private func finishRewind() {
        rewindTask = nil
        rewindProgress = nil
        state = .live
        AppLog.rewind.debug("Rewind terminado; relógio sincronizado com a hora real")
        emit(.rewindFinished)
    }

    // MARK: - Configurações e ciclo de vida

    /// Abre as configurações (só a partir da tela preta).
    func openSettings() {
        guard state.isDark else { return }
        cancelAllTasks()
        secretInput.setMode(configuration.inputMode)
        state = .settings
    }

    func closeSettings() {
        guard state == .settings else { return }
        resetToDark()
    }

    func sceneDidEnterBackground() {
        guard configuration.returnToDarkOnBackground, state != .settings else { return }
        resetToDark()
    }

    /// Volta para a tela preta limpa.
    func resetToDark() {
        cancelAllTasks()
        _ = secretInput.handle(.reset)
        rewindProgress = nil
        state = .dark
        AppLog.trick.debug("Reset para o preto")
    }

    /// Força um estado sem animação nem tarefas (só para os estados de demonstração).
    func applyDemoState(_ newState: TrickState, rewindProgress progress: RewindProgress? = nil) {
        cancelAllTasks()
        _ = secretInput.handle(.reset)
        rewindProgress = progress
        state = newState
    }

    // MARK: - Internos

    private func apply(_ action: SecretInputAction) {
        switch action {
        case .none:
            return
        case let .tapCounted(count):
            inputFeedbackCount += 1
            emit(.inputTap(count: count))
            scheduleTimeout()
        case let .digitRegistered(digit):
            inputFeedbackCount += 1
            emit(.digitRegistered(digit))
            scheduleTimeout()
        case let .armed(value):
            cancelTimeout()
            state = .armed(offset: value)
            inputFeedbackCount += 1
            AppLog.input.debug("Número armado")
            emit(.armed(value))
        case let .wake(value):
            cancelTimeout()
            wake(offset: value)
        case .error:
            cancelTimeout()
            state = .dark
            emit(.error)
        case .reset:
            cancelTimeout()
            state = .dark
            emit(.reset)
        }
    }

    private func wake(offset: Int) {
        state = .lockScreen(offset: offset)
        AppLog.trick.debug("Tela de bloqueio acesa")
        emit(.wake)
        scheduleAutoRewind()
    }

    private func emit(_ feedback: TrickFeedback) {
        onFeedback?(feedback)
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        let delay = configuration.inputTimeout
        guard delay > 0 else {
            timeoutTask = nil
            return
        }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: TrickController.nanoseconds(delay))
            if Task.isCancelled { return }
            self?.handleInputTimeout()
        }
    }

    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private func scheduleAutoRewind() {
        cancelAutoRewind()
        guard let delay = configuration.autoRewindDelay, delay > 0 else { return }
        autoRewindTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: TrickController.nanoseconds(delay))
            if Task.isCancelled { return }
            self?.triggerRewind()
        }
    }

    private func cancelAutoRewind() {
        autoRewindTask?.cancel()
        autoRewindTask = nil
    }

    private func cancelAllTasks() {
        cancelTimeout()
        cancelAutoRewind()
        rewindTask?.cancel()
        rewindTask = nil
    }

    private static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return UInt64(seconds * 1_000_000_000)
    }
}
