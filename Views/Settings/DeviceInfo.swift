import UIKit

/// Informações do aparelho para a seção "Sobre / diagnóstico".
@MainActor
enum DeviceInfo {
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// Identificador do modelo (ex.: "iPhone16,1"). No simulador, o do aparelho simulado.
    static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        var identifier = ""
        for child in mirror.children {
            guard let value = child.value as? Int8, value != 0 else { continue }
            identifier.append(Character(UnicodeScalar(UInt8(bitPattern: value))))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }

    static var systemVersion: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    static var screenDescription: String {
        let screen = currentScreen
        let size = screen.bounds.size
        return "\(format(size.width)) × \(format(size.height)) pt @\(format(screen.scale))x"
    }

    static var safeAreaDescription: String {
        let insets = ScreenMetrics.windowSafeAreaInsets()
        return "topo \(format(insets.top)) · base \(format(insets.bottom)) · lados \(format(insets.left))/\(format(insets.right))"
    }

    private static var currentScreen: UIScreen {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first?.screen ?? UIScreen.main
    }

    private static func format(_ value: CGFloat) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", Double(value))
    }
}
