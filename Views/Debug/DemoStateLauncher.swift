import Foundation

/// Estados de demonstração abertos por launch arguments, usados pelo job de screenshots da CI:
///
///     -demoState dark-grid
///     -demoState lock -demoOffset 8 -demoTime 14:30
///     -demoState rewinding-mid [-demoOffset 8 -demoTime 14:30]
///     -demoState live -demoTime 14:22
///     -demoState settings
///     -demoState calibration
///
/// `-demoTime` é a hora REAL simulada (congelada); no estado `lock` a tela mostra demoTime + demoOffset.
/// Só existe em builds Debug: no Release (o .ipa) o parser sempre devolve nil.
enum DemoState: String {
    case darkGrid = "dark-grid"
    case lock
    case rewindingMid = "rewinding-mid"
    case live
    case settings
    case calibration
}

struct DemoLaunch {
    let state: DemoState
    let offset: Int
    let time: Date

    /// Lido uma única vez dos argumentos do processo.
    static let current: DemoLaunch? = parse(ProcessInfo.processInfo.arguments)

    static func parse(_ arguments: [String], calendar: Calendar = .current, today: Date = Date()) -> DemoLaunch? {
        #if DEBUG
        guard let raw = value(after: "-demoState", in: arguments), let state = DemoState(rawValue: raw) else {
            return nil
        }
        let offset = value(after: "-demoOffset", in: arguments).flatMap { Int($0) } ?? 8
        let defaultTime = state == .live ? "14:22" : "14:30"
        let timeText = value(after: "-demoTime", in: arguments) ?? defaultTime
        let time = parseTime(timeText, calendar: calendar, today: today) ?? today
        return DemoLaunch(state: state, offset: min(max(offset, 1), 59), time: time)
        #else
        return nil
        #endif
    }

    /// "HH:mm" no dia de hoje (segundos = 5, para não cair exatamente na virada do minuto).
    static func parseTime(_ text: String, calendar: Calendar, today: Date) -> Date? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 5, of: today)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// Mostra a grade de treino na tela preta.
    var showsGrid: Bool { state == .darkGrid }

    /// Abre a calibração por cima das configurações.
    var opensCalibration: Bool { state == .calibration }
}

@MainActor
enum DemoStateLauncher {
    /// Controller da app: normal, ou já posicionado no estado de demonstração pedido.
    static func makeController(for demo: DemoLaunch? = DemoLaunch.current) -> TrickController {
        guard let demo else { return TrickController() }
        let frozen = demo.time
        let controller = TrickController(now: { frozen }, frozenNow: frozen)
        switch demo.state {
        case .darkGrid:
            controller.applyDemoState(.dark)
        case .lock:
            controller.applyDemoState(.lockScreen(offset: demo.offset))
        case .rewindingMid:
            let intervals = RewindPlanner.intervals(steps: demo.offset, totalDuration: RewindPlanner.defaultDuration)
            var progress = RewindProgress(startedAt: frozen, offsetMinutes: demo.offset, intervals: intervals, calendar: controller.calendar)
            for _ in 0..<(demo.offset / 2) {
                progress.advance(now: frozen, calendar: controller.calendar)
            }
            controller.applyDemoState(.rewinding(from: demo.offset), rewindProgress: progress)
        case .live:
            controller.applyDemoState(.live)
        case .settings, .calibration:
            controller.applyDemoState(.settings)
        }
        return controller
    }
}
