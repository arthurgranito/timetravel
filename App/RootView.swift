import SwiftUI
import UIKit

/// Raiz: tela preta, tela de bloqueio falsa, configurações e o ciclo de vida do app.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var controller = DemoStateLauncher.makeController()
    @State private var settings = AppSettings()
    @State private var wallpapers = WallpaperStore()
    @State private var haptics = Haptics()
    @State private var torch = Torch()
    @State private var brightness = ScreenBrightness()
    /// Número sorteado pelo "Ensaiar" (grade visível até o rewind terminar).
    @State private var rehearsalNumber: Int?

    var body: some View {
        let state = controller.state
        ZStack {
            Color.black.ignoresSafeArea()

            if state == .settings {
                SettingsView(
                    settings: settings,
                    wallpapers: wallpapers,
                    opensCalibrationOnAppear: DemoLaunch.current?.opensCalibration ?? false,
                    onRehearse: {
                        startRehearsal()
                    },
                    onClose: {
                        controller.closeSettings()
                    }
                )
            } else {
                magicScreens(state: state)
            }
        }
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            configure()
            brightness.save()
            applyIdleTimer(active: true)
        }
        .onChange(of: settings.data) { _, _ in
            settings.save()
            configure()
            applyIdleTimer(active: scenePhase == .active)
        }
        .onChange(of: state) { _, newState in
            stateChanged(newState)
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    private func magicScreens(state: TrickState) -> some View {
        GeometryReader { proxy in
            let metrics = ScreenMetrics(proxy: proxy)
            ZStack {
                Color.black

                if state.showsLockScreen {
                    LockScreenView(
                        controller: controller,
                        style: settings.data.style,
                        preferences: settings.data.preferences,
                        wallpaper: wallpapers.wallpaper,
                        metrics: metrics,
                        haptics: haptics,
                        torch: torch
                    )
                    .transition(.opacity)
                }

                if state.isDark {
                    DarkScreenView(
                        controller: controller,
                        preferences: darkScreenPreferences,
                        settingsGesture: settings.data.settingsGesture,
                        rehearsalNumber: rehearsalNumber
                    )
                }
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
            .animation(state.showsLockScreen ? Animation.easeOut(duration: 0.25) : nil, value: state.showsLockScreen)
        }
        .ignoresSafeArea()
        .defersSystemGestures(on: .bottom)
        .dynamicTypeSize(.large)
        .environment(\.legibilityWeight, .regular)
    }

    /// No ensaio, a grade fica visível mesmo com o modo treino desligado.
    private var darkScreenPreferences: MagicPreferences {
        var preferences = settings.data.preferences
        if rehearsalNumber != nil || DemoLaunch.current?.showsGrid == true {
            preferences.showsTrainingGrid = true
        }
        return preferences
    }

    private func configure() {
        controller.updateConfiguration(settings.data.trickConfiguration)
        let hapticPreferences = settings.data.preferences.haptics
        let hapticsService = haptics
        controller.onFeedback = { feedback in
            hapticsService.handle(feedback, preferences: hapticPreferences)
        }
        hapticsService.prepare()
    }

    private func startRehearsal() {
        rehearsalNumber = Int.random(in: settings.data.inputMode.validRange)
        controller.closeSettings()
    }

    private func stateChanged(_ newState: TrickState) {
        if newState.isDark {
            brightness.save()
        }
        if newState.showsLockScreen {
            brightness.applySaved()
        }
        if newState == .live || newState == .settings {
            rehearsalNumber = nil
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            applyIdleTimer(active: true)
        case .background:
            applyIdleTimer(active: false)
            torch.setOn(false)
            brightness.restore()
            controller.sceneDidEnterBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func applyIdleTimer(active: Bool) {
        UIApplication.shared.isIdleTimerDisabled = active && settings.data.preferences.keepScreenAwake
    }
}
