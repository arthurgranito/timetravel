import SwiftUI

/// Status bar falsa: operadora à esquerda; sinal, Wi-Fi e bateria à direita.
/// Nunca mostra a hora, em nenhum aparelho.
struct FakeStatusBar: View {
    let style: LockScreenStyle
    let battery: BatteryMonitor
    let sidePadding: CGFloat

    var body: some View {
        let fontSize = style.statusBarFontSize
        let scale = fontSize / 16
        HStack(spacing: 0) {
            Text(style.carrierName)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 8)
            HStack(spacing: 5 * scale) {
                Image(systemName: "cellularbars", variableValue: Double(min(max(style.signalBars, 0), 4)) / 4.0)
                    .font(.system(size: fontSize * 0.82, weight: .semibold))
                if style.showsWiFi {
                    Image(systemName: "wifi")
                        .font(.system(size: fontSize * 0.82, weight: .semibold))
                }
                BatteryIcon(
                    level: battery.level,
                    percentage: battery.percentage,
                    isCharging: battery.isCharging,
                    isLowPowerMode: battery.isLowPowerMode,
                    showsPercentage: style.showsBatteryPercentage,
                    scale: scale
                )
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, sidePadding)
    }
}

/// Ícone de bateria desenhado à mão, no estilo do iOS 17/18.
struct BatteryIcon: View {
    let level: Double
    let percentage: Int
    let isCharging: Bool
    let isLowPowerMode: Bool
    let showsPercentage: Bool
    let scale: CGFloat

    private var fillColor: Color {
        if isCharging {
            return Color(red: 0.20, green: 0.78, blue: 0.35)
        }
        if isLowPowerMode {
            return Color(red: 1.0, green: 0.80, blue: 0.0)
        }
        if level <= 0.2 {
            return Color(red: 1.0, green: 0.23, blue: 0.19)
        }
        return Color.white
    }

    var body: some View {
        let width = 25 * scale
        let height = 12 * scale
        let clamped = CGFloat(min(max(level, 0), 1))
        HStack(spacing: 1 * scale) {
            Group {
                if showsPercentage {
                    solidBody(width: width, height: height, fraction: clamped)
                } else {
                    outlinedBody(width: width, height: height, fraction: clamped)
                }
            }
            RoundedRectangle(cornerRadius: 1 * scale, style: .continuous)
                .fill(Color.white.opacity(0.4))
                .frame(width: 1.5 * scale, height: 4 * scale)
        }
    }

    /// Estilo clássico: contorno fino e preenchimento interno.
    private func outlinedBody(width: CGFloat, height: CGFloat, fraction: CGFloat) -> some View {
        let corner = 3.8 * scale
        let inset = 2 * scale
        let innerWidth = width - inset * 2
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1 * scale)
            RoundedRectangle(cornerRadius: 2 * scale, style: .continuous)
                .fill(fillColor)
                .frame(width: max(innerWidth * fraction, 1.5 * scale), height: height - inset * 2)
                .padding(.leading, inset)
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8 * scale, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }

    /// Estilo com porcentagem: corpo sólido com o número dentro.
    private func solidBody(width: CGFloat, height: CGFloat, fraction: CGFloat) -> some View {
        let corner = 4 * scale
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.35))
            Rectangle()
                .fill(fillColor)
                .frame(width: width * fraction)
            Text("\(percentage)")
                .font(.system(size: 9.5 * scale, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.black)
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
