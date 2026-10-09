import SwiftUI
import UIKit

enum FontWeightOption: String, CaseIterable, Identifiable, Codable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ultraLight:
            return "Ultrafino"
        case .thin:
            return "Fino"
        case .light:
            return "Leve"
        case .regular:
            return "Regular"
        case .medium:
            return "Médio"
        case .semibold:
            return "Seminegrito"
        case .bold:
            return "Negrito"
        case .heavy:
            return "Pesado"
        case .black:
            return "Black"
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        }
    }
}

enum FontDesignOption: String, CaseIterable, Identifiable, Codable {
    case standard, rounded, serif, monospaced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard:
            return "Padrão"
        case .rounded:
            return "Arredondada"
        case .serif:
            return "Serifa"
        case .monospaced:
            return "Monoespaçada"
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .standard:
            return .default
        case .rounded:
            return .rounded
        case .serif:
            return .serif
        case .monospaced:
            return .monospaced
        }
    }
}

/// Cor serializável (para salvar nas configurações).
struct RGBAColor: Equatable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension RGBAColor {
    /// Converte uma cor do ColorPicker (componentes limitados a 0...1).
    init(_ color: Color) {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        if !UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            red = 1
            green = 1
            blue = 1
            alpha = 1
        }
        func clamp(_ value: CGFloat) -> Double {
            Double(min(max(value, 0), 1))
        }
        self.init(red: clamp(red), green: clamp(green), blue: clamp(blue), alpha: clamp(alpha))
    }
}

/// Aparência da tela de bloqueio falsa. Os ajustes de posição são somados
/// às posições padrão calculadas para cada aparelho (LockScreenLayout).
struct LockScreenStyle: Equatable {
    // Relógio
    var clockSize: CGFloat = 104
    var clockWeight: FontWeightOption = .semibold
    var clockDesign: FontDesignOption = .rounded
    var clockKerning: CGFloat = 0
    var clockYOffset: CGFloat = 0
    var clockColor: RGBAColor = .white
    var clockFormat = ClockFormatOptions()

    // Data
    var dateSize: CGFloat = 20
    var dateWeight: FontWeightOption = .semibold
    var dateYOffset: CGFloat = 0
    var dateOpacity: Double = 0.85
    var dateFormat = DateFormatOptions()

    // Status bar
    var carrierName: String = "TIM"
    var signalBars: Int = 4
    var showsWiFi: Bool = true
    var showsBatteryPercentage: Bool = false
    var statusBarYOffset: CGFloat = 0
    var statusBarFontSize: CGFloat = 16
    var statusBarSideOffset: CGFloat = 0

    // Cadeado
    var showsPadlock: Bool = true
    var padlockYOffset: CGFloat = 0
    var padlockSize: CGFloat = 15

    // Botões de lanterna e câmera
    var quickButtonSize: CGFloat = 50
    var quickButtonBottomOffset: CGFloat = 0
    var quickButtonSideOffset: CGFloat = 0

    // Wallpaper
    /// Escurecimento do wallpaper (0...0.3).
    var wallpaperDim: Double = 0

    /// "Deslize para cima para abrir" na parte de baixo.
    var showsUnlockHint: Bool = false

    /// Volta só os ajustes de calibração (tamanhos, pesos, posições) para o padrão,
    /// mantendo textos, formatos e opções de conteúdo.
    mutating func resetCalibration() {
        let defaults = LockScreenStyle()
        clockSize = defaults.clockSize
        clockWeight = defaults.clockWeight
        clockDesign = defaults.clockDesign
        clockKerning = defaults.clockKerning
        clockYOffset = defaults.clockYOffset
        clockColor = defaults.clockColor
        dateSize = defaults.dateSize
        dateWeight = defaults.dateWeight
        dateYOffset = defaults.dateYOffset
        dateOpacity = defaults.dateOpacity
        statusBarYOffset = defaults.statusBarYOffset
        statusBarFontSize = defaults.statusBarFontSize
        statusBarSideOffset = defaults.statusBarSideOffset
        padlockYOffset = defaults.padlockYOffset
        padlockSize = defaults.padlockSize
        quickButtonSize = defaults.quickButtonSize
        quickButtonBottomOffset = defaults.quickButtonBottomOffset
        quickButtonSideOffset = defaults.quickButtonSideOffset
    }
}

/// Posições (centro, em pt, coordenadas da tela inteira) de cada elemento.
struct LockScreenLayout {
    let metrics: ScreenMetrics
    let style: LockScreenStyle

    var width: CGFloat { metrics.size.width }
    var height: CGFloat { metrics.size.height }

    /// Linha central da status bar, alinhada com a Dynamic Island / notch.
    var statusBarCenterY: CGFloat {
        let base: CGFloat
        if metrics.hasDynamicIsland {
            base = 30
        } else if metrics.hasHomeButton {
            base = 11
        } else {
            base = 24
        }
        return base + style.statusBarYOffset
    }

    var statusBarSidePadding: CGFloat {
        (metrics.hasHomeButton ? 8 : 30) + style.statusBarSideOffset
    }

    var padlockCenterY: CGFloat {
        let base = metrics.hasHomeButton ? 34 : metrics.safeTop + 14
        return base + style.padlockYOffset
    }

    private var baseDateCenterY: CGFloat {
        metrics.hasHomeButton ? 72 : metrics.safeTop + 58
    }

    var dateCenterY: CGFloat {
        baseDateCenterY + style.dateYOffset
    }

    var clockCenterY: CGFloat {
        baseDateCenterY + 72 + style.clockYOffset
    }

    var quickButtonCenterY: CGFloat {
        let fromBottom: CGFloat = metrics.hasHomeButton ? 46 : 77
        return height - fromBottom - style.quickButtonBottomOffset
    }

    var quickButtonInset: CGFloat {
        let edge: CGFloat = metrics.hasHomeButton ? 30 : 46
        return edge + style.quickButtonSideOffset + style.quickButtonSize / 2
    }

    var unlockHintCenterY: CGFloat {
        height - (metrics.hasHomeButton ? 22 : 44)
    }

    /// Zona onde o swipe de rewind pode começar: metade de baixo, acima dos 40pt finais.
    func isValidSwipeStart(_ point: CGPoint) -> Bool {
        point.y >= height / 2 && point.y <= height - 40
    }
}

// MARK: - Codable tolerante (campos ausentes usam o padrão)

extension LockScreenStyle: Codable {
    enum CodingKeys: String, CodingKey {
        case clockSize, clockWeight, clockDesign, clockKerning, clockYOffset, clockColor, clockFormat
        case dateSize, dateWeight, dateYOffset, dateOpacity, dateFormat
        case carrierName, signalBars, showsWiFi, showsBatteryPercentage, statusBarYOffset, statusBarFontSize, statusBarSideOffset
        case showsPadlock, padlockYOffset, padlockSize
        case quickButtonSize, quickButtonBottomOffset, quickButtonSideOffset
        case wallpaperDim, showsUnlockHint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = LockScreenStyle()
        self.init()
        clockSize = container.value(.clockSize, default: fallback.clockSize)
        clockWeight = container.value(.clockWeight, default: fallback.clockWeight)
        clockDesign = container.value(.clockDesign, default: fallback.clockDesign)
        clockKerning = container.value(.clockKerning, default: fallback.clockKerning)
        clockYOffset = container.value(.clockYOffset, default: fallback.clockYOffset)
        clockColor = container.value(.clockColor, default: fallback.clockColor)
        clockFormat = container.value(.clockFormat, default: fallback.clockFormat)
        dateSize = container.value(.dateSize, default: fallback.dateSize)
        dateWeight = container.value(.dateWeight, default: fallback.dateWeight)
        dateYOffset = container.value(.dateYOffset, default: fallback.dateYOffset)
        dateOpacity = container.value(.dateOpacity, default: fallback.dateOpacity)
        dateFormat = container.value(.dateFormat, default: fallback.dateFormat)
        carrierName = container.value(.carrierName, default: fallback.carrierName)
        signalBars = container.value(.signalBars, default: fallback.signalBars)
        showsWiFi = container.value(.showsWiFi, default: fallback.showsWiFi)
        showsBatteryPercentage = container.value(.showsBatteryPercentage, default: fallback.showsBatteryPercentage)
        statusBarYOffset = container.value(.statusBarYOffset, default: fallback.statusBarYOffset)
        statusBarFontSize = container.value(.statusBarFontSize, default: fallback.statusBarFontSize)
        statusBarSideOffset = container.value(.statusBarSideOffset, default: fallback.statusBarSideOffset)
        showsPadlock = container.value(.showsPadlock, default: fallback.showsPadlock)
        padlockYOffset = container.value(.padlockYOffset, default: fallback.padlockYOffset)
        padlockSize = container.value(.padlockSize, default: fallback.padlockSize)
        quickButtonSize = container.value(.quickButtonSize, default: fallback.quickButtonSize)
        quickButtonBottomOffset = container.value(.quickButtonBottomOffset, default: fallback.quickButtonBottomOffset)
        quickButtonSideOffset = container.value(.quickButtonSideOffset, default: fallback.quickButtonSideOffset)
        wallpaperDim = container.value(.wallpaperDim, default: fallback.wallpaperDim)
        showsUnlockHint = container.value(.showsUnlockHint, default: fallback.showsUnlockHint)
    }
}
