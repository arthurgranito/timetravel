import SwiftUI

/// Relógio grande da tela de bloqueio.
struct LockClockView: View {
    let text: String
    let style: LockScreenStyle
    /// true durante o rewind: os dígitos "descem" na transição.
    let countsDown: Bool
    let animationDuration: Double

    var body: some View {
        Text(text)
            .font(.system(size: style.clockSize, weight: style.clockWeight.fontWeight, design: style.clockDesign.fontDesign))
            .kerning(style.clockKerning)
            .monospacedDigit()
            .foregroundStyle(style.clockColor.color)
            .lineLimit(1)
            .fixedSize()
            .contentTransition(.numericText(countsDown: countsDown))
            .animation(.smooth(duration: animationDuration), value: text)
    }
}
