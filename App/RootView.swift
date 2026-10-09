import SwiftUI
import UIKit

/// Raiz: tela preta, tela de bloqueio falsa, e o ciclo de vida do app.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var controller = TrickController()
    @State private var haptics = Haptics()
    @State private var torch = Torch()
    @State private var brightness = ScreenBrightness()
    @State private var style = LockScreenStyle()
    @State private var preferences = MagicPreferences()

    var body: some View {
        let state = controller.state
        GeometryReader { proxy in
            let metrics = ScreenMetrics(proxy: proxy)
            ZStack {
                Color.black

                if state.showsLockScreen {
                    LockScreenView(
                        controller: controller,
                        style: style,
                        preferences: preferences,
                        wallpaper: nil,
                        metrics: metrics,
                        haptics: haptics,
                        torch: torch
                    )
                    .transition(.opacity)
                }

                if state.isDark {
                    DarkScreenView(controller: controller, preferences: preferences)
                }
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
            .animation(state.showsLockScreen ? Animation.easeOut(duration: 0.25) : nil, value: state.showsLockScreen)
        }
        .ignoresSafeArea()
        .background(Color.black)
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .defersSystemGestures(on: .bottom)
        .dynamicTypeSize(.large)
        .environment(\.legibilityWeight, .regular)
        .onAppear {
            configure()
            brightness.save()
            applyIdleTimer(active: true)
        }
        .onChange(of: preferences) { _, _ in
            configure()
            applyIdleTimer(active: scenePhase == .active)
        }
        .onChange(of: state.isDark) { _, isDark in
            if isDark {
                brightness.save()
            }
        }
        .onChange(of: state.showsLockScreen) { _, showsLock in
            if showsLock {
                brightness.applySaved()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    private func configure() {
        var configuration = controller.configuration
        configuration.autoRewindDelay = preferences.rewindTrigger == .automatic ? preferences.autoRewindDelay : nil
        controller.updateConfiguration(configuration)

        let hapticPreferences = preferences.haptics
        let hapticsService = haptics
        controller.onFeedback = { feedback in
            hapticsService.handle(feedback, preferences: hapticPreferences)
        }
        hapticsService.prepare()
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
        UIApplication.shared.isIdleTimerDisabled = active && preferences.keepScreenAwake
    }
}
