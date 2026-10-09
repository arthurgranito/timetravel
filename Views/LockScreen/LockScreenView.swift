import Combine
import SwiftUI
import UIKit

/// Tela de bloqueio falsa: wallpaper, status bar, cadeado, data, relógio e botões.
/// Mostra real + N no estado lockScreen, anima no rewinding e fica sincronizada no live.
struct LockScreenView: View {
    let controller: TrickController
    let style: LockScreenStyle
    let preferences: MagicPreferences
    let wallpaper: UIImage?
    let metrics: ScreenMetrics
    let haptics: Haptics
    let torch: Torch

    @State private var battery = BatteryMonitor()
    @State private var wakeScale: CGFloat = 1.03
    @State private var rewindZoom: CGFloat = 1.0
    @State private var isPadlockOpen = false
    @State private var glitchOffset: CGFloat = 0
    @State private var glitchOpacity: Double = 1
    @State private var glitchTask: Task<Void, Never>?

    var body: some View {
        let state = controller.state
        let rewindStep = controller.rewindProgress?.completedSteps ?? 0
        let isRewinding = isRewindingState(state)
        let layout = LockScreenLayout(metrics: metrics, style: style)

        TimelineView(.everyMinute) { context in
            let now = max(context.date, Date())
            let shown = controller.displayedMinute(now: now)
            content(shown: shown, layout: layout, isRewinding: isRewinding)
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .contentShape(Rectangle())
        .simultaneousGesture(swipeUpGesture(layout: layout))
        .gesture(liveResetGesture)
        .onAppear {
            battery.start()
            withAnimation(.easeOut(duration: 0.35)) {
                wakeScale = 1.0
            }
        }
        .onReceive(batteryChanges) { _ in
            battery.refresh()
        }
        .onChange(of: isRewinding) { _, rewinding in
            rewindStateChanged(rewinding)
        }
        .onChange(of: rewindStep) { _, step in
            if step > 0 {
                playGlitch()
            }
        }
        .onDisappear {
            glitchTask?.cancel()
            if torch.isOn {
                torch.setOn(false)
            }
        }
    }

    /// Mudanças de nível, carregamento e modo de pouca energia, sempre entregues na main thread.
    private var batteryChanges: AnyPublisher<Notification, Never> {
        let center = NotificationCenter.default
        return Publishers.Merge3(
            center.publisher(for: UIDevice.batteryLevelDidChangeNotification),
            center.publisher(for: UIDevice.batteryStateDidChangeNotification),
            center.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
        )
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    // MARK: - Camadas

    @ViewBuilder
    private func content(shown: Date, layout: LockScreenLayout, isRewinding: Bool) -> some View {
        let calendar = controller.calendar
        let timeText = TimeEngine.timeString(for: shown, calendar: calendar, options: style.clockFormat)
        let dateText = TimeEngine.dateString(for: shown, calendar: calendar, options: style.dateFormat)
        let centerX = metrics.size.width / 2

        ZStack {
            wallpaperLayer

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
            .offset(x: glitchOffset)
            .opacity(glitchOpacity)
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if preferences.rewindTrigger == .doubleTapClock {
                    controller.triggerRewind()
                }
            }
            .position(x: centerX, y: layout.clockCenterY)

            QuickActionButton(
                systemImage: torch.isOn ? "flashlight.on.fill" : "flashlight.off.fill",
                size: style.quickButtonSize,
                isActive: torch.isOn
            )
            .onLongPressGesture(minimumDuration: 0.35) {
                haptics.tap()
                torch.toggle()
            }
            .position(x: layout.quickButtonInset, y: layout.quickButtonCenterY)

            QuickActionButton(systemImage: "camera.fill", size: style.quickButtonSize)
                .onLongPressGesture(minimumDuration: 0.35) {
                    haptics.tap()
                }
                .position(x: metrics.size.width - layout.quickButtonInset, y: layout.quickButtonCenterY)

            if style.showsUnlockHint && isLockedState(controller.state) {
                UnlockHintView()
                    .position(x: centerX, y: layout.unlockHintCenterY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
    }

    private var wallpaperLayer: some View {
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
            .scaleEffect(wakeScale * rewindZoom)
            .clipped()

            Color.black.opacity(min(max(style.wallpaperDim, 0), 0.3))
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .clipped()
        .allowsHitTesting(false)
    }

    // MARK: - Gestos

    private func swipeUpGesture(layout: LockScreenLayout) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard preferences.rewindTrigger == .swipeUp else { return }
                guard layout.isValidSwipeStart(value.startLocation) else { return }
                let vertical = value.translation.height
                guard vertical <= -60, abs(vertical) > abs(value.translation.width) else { return }
                controller.triggerRewind()
            }
    }

    private var liveResetGesture: some Gesture {
        LongPressGesture(minimumDuration: preferences.liveResetDuration)
            .onEnded { _ in
                guard preferences.liveResetEnabled, controller.state == .live else { return }
                controller.handleResetGesture()
            }
    }

    // MARK: - Efeitos

    private func rewindStateChanged(_ rewinding: Bool) {
        if rewinding {
            if preferences.effects.padlockOpens {
                withAnimation(.easeOut(duration: 0.3)) {
                    isPadlockOpen = true
                }
            }
            if preferences.effects.wallpaperZoom {
                let duration = RewindPlanner.effectiveDuration(controller.configuration.rewindDuration)
                withAnimation(.easeInOut(duration: duration)) {
                    rewindZoom = 1.04
                }
            }
        } else if rewindZoom != 1.0 {
            withAnimation(.easeOut(duration: 0.6)) {
                rewindZoom = 1.0
            }
        }
    }

    private func playGlitch() {
        guard preferences.effects.glitch else { return }
        glitchTask?.cancel()
        glitchOffset = Bool.random() ? 1.5 : -1.5
        glitchOpacity = 0.82
        glitchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.08)) {
                glitchOffset = 0
                glitchOpacity = 1
            }
        }
    }

    private func isRewindingState(_ state: TrickState) -> Bool {
        if case .rewinding = state {
            return true
        }
        return false
    }

    private func isLockedState(_ state: TrickState) -> Bool {
        if case .lockScreen = state {
            return true
        }
        return false
    }
}
