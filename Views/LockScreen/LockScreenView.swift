import Combine
import SwiftUI
import UIKit

/// Tela de bloqueio da mágica: mostra real + N no estado lockScreen,
/// anima no rewinding e fica sincronizada com a hora real no live.
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
            let now = controller.clockDate(timelineDate: context.date)
            LockScreenCanvas(
                shownMinute: controller.displayedMinute(now: now),
                calendar: controller.calendar,
                style: style,
                wallpaper: wallpaper,
                metrics: metrics,
                battery: battery,
                isPadlockOpen: isPadlockOpen,
                isRewinding: isRewinding,
                wallpaperScale: wakeScale * rewindZoom,
                clockOffset: glitchOffset,
                clockOpacity: glitchOpacity,
                showsUnlockHint: style.showsUnlockHint && isLockedState(state),
                torchIsOn: torch.isOn,
                onClockDoubleTap: {
                    if preferences.rewindTrigger == .doubleTapClock {
                        controller.triggerRewind()
                    }
                },
                onTorch: {
                    haptics.tap()
                    torch.toggle()
                },
                onCamera: {
                    haptics.tap()
                }
            )
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .contentShape(Rectangle())
        .simultaneousGesture(swipeUpGesture(layout: layout))
        .gesture(liveResetGesture)
        .onAppear {
            battery.start()
            // Se a tela já aparece depois do desbloqueio (ex.: estados de demonstração), o cadeado já está aberto.
            if preferences.effects.padlockOpens && (isRewinding || state == .live) {
                isPadlockOpen = true
            }
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
