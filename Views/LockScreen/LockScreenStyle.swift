import SwiftUI

enum FontWeightOption: String, CaseIterable, Identifiable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var id: String { rawValue }

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

enum FontDesignOption: String, CaseIterable, Identifiable {
    case standard, rounded, serif, monospaced

    var id: String { rawValue }

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
