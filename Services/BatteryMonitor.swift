import UIKit
import Observation

/// Nível e estado reais da bateria para a status bar falsa.
@MainActor
@Observable
final class BatteryMonitor {
    /// 0...1 (no simulador, onde o nível é desconhecido, vale 1).
    private(set) var level: Double = 1
    private(set) var isCharging: Bool = false
    private(set) var isLowPowerMode: Bool = false

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
    }

    func refresh() {
        let raw = UIDevice.current.batteryLevel
        level = raw < 0 ? 1 : Double(min(max(raw, 0), 1))
        let state = UIDevice.current.batteryState
        isCharging = state == .charging || state == .full
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var percentage: Int {
        Int((level * 100).rounded())
    }
}
