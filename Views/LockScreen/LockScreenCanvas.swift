import SwiftUI
import UIKit

/// Desenho puro da tela de bloqueio para um minuto já calculado.
/// Usado pela tela da mágica (LockScreenView) e pela calibração (com hora congelada).
struct LockScreenCanvas: View {
    let shownMinute: Date
    let calendar: Calendar
    let style: LockScreenStyle
    let wallpaper: UIImage?
    let metrics: ScreenMetrics
    let battery: BatteryMonitor
    var isPadlockOpen: Bool = false
    var isRewinding: Bool = false
    var wallpaperScale: CGFloat = 1
    var clockOffset: CGFloat = 0
    var clockOpacity: Double = 1
    var showsUnlockHint: Bool = false
    var torchIsOn: Bool = false
    var onClockDoubleTap: (@MainActor () -> Void)? = nil
    var onTorch: (@MainActor () -> Void)? = nil
    var onCamera: (@MainActor () -> Void)? = nil

    var body: some View {
        let layout = LockScreenLayout(metrics: metrics, style: style)
        let timeText = TimeEngine.timeString(for: shownMinute, calendar: calendar, options: style.clockFormat)
        let dateText = TimeEngine.dateString(for: shownMinute, calendar: calendar, options: style.dateFormat)
        let centerX = metrics.size.width / 2

        ZStack {
            LockWallpaperView(wallpaper: wallpaper, metrics: metrics, scale: wallpaperScale, dim: style.wallpaperDim)

            FakeStatusBar(style: style, battery: battery, sidePadding: layout.statusBarSidePadding)
                .frame(width: metrics.size.width)
                .position(x: centerX, y: layout.statusBarCenterY)

            if style.showsPadlock {
                PadlockView(isOpen: isPadlockOpen, size: style.padlockSize)
                    .position(x: centerX, y: layout.padlockCenterY)
            }

            LockDateView(text: dateText, style: style)
                .position(x: centerX, y: layout.dateCenterY)

            LockClockView(
                text: timeText,
                style: style,
                countsDown: isRewinding,
                animationDuration: isRewinding ? 0.2 : 0.35
            )
            .offset(x: clockOffset)
            .opacity(clockOpacity)
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onClockDoubleTap?()
            }
            .position(x: centerX, y: layout.clockCenterY)

            QuickActionButton(
                systemImage: torchIsOn ? "flashlight.on.fill" : "flashlight.off.fill",
                size: style.quickButtonSize,
                isActive: torchIsOn
            )
            .onLongPressGesture(minimumDuration: 0.35) {
                onTorch?()
            }
            .position(x: layout.quickButtonInset, y: layout.quickButtonCenterY)

            QuickActionButton(systemImage: "camera.fill", size: style.quickButtonSize)
                .onLongPressGesture(minimumDuration: 0.35) {
                    onCamera?()
                }
                .position(x: metrics.size.width - layout.quickButtonInset, y: layout.quickButtonCenterY)

            if showsUnlockHint {
                UnlockHintView()
                    .position(x: centerX, y: layout.unlockHintCenterY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .dynamicTypeSize(.large)
        .environment(\.legibilityWeight, .regular)
        .environment(\.colorScheme, .dark)
    }
}

/// Wallpaper ocupando a tela toda (ou gradiente escuro neutro), com escurecimento opcional.
struct LockWallpaperView: View {
    let wallpaper: UIImage?
    let metrics: ScreenMetrics
    let scale: CGFloat
    let dim: Double

    var body: some View {
        ZStack {
            Group {
                if let wallpaper {
                    Image(uiImage: wallpaper)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.17, blue: 0.22),
                            Color(red: 0.07, green: 0.07, blue: 0.10),
                            Color(red: 0.02, green: 0.02, blue: 0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
            .scaleEffect(scale)
            .clipped()

            Color.black.opacity(min(max(dim, 0), 0.3))
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .clipped()
        .allowsHitTesting(false)
    }
}
