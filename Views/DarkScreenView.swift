import SwiftUI

/// Tela preta pura (#000000). Recebe a entrada secreta.
struct DarkScreenView: View {
    let controller: TrickController
    let preferences: MagicPreferences
    var settingsGesture: SettingsGesture = .threeTwoFingerTaps
    /// Número sorteado no modo "Ensaiar" (mostra a grade e o número a fazer).
    var rehearsalNumber: Int? = nil

    @State private var canvas = InputCanvas(size: .zero)
    @State private var indicatorVisible = false
    @State private var indicatorTask: Task<Void, Never>?

    var body: some View {
        let feedbackCount = controller.inputFeedbackCount
        ZStack {
            Color.black

            if preferences.showsTrainingGrid && canvas.size.width > 0 {
                TrainingOverlay(controller: controller, canvas: canvas, rehearsalNumber: rehearsalNumber)
                    .allowsHitTesting(false)
            }

            if preferences.showsSecretIndicator && indicatorVisible {
                Circle()
                    .fill(Color(white: 0.18))
                    .frame(width: 3, height: 3)
                    .position(
                        x: max(canvas.size.width - canvas.safeAreaInsets.trailing - 14, 0),
                        y: max(canvas.size.height - canvas.safeAreaInsets.bottom - 14, 0)
                    )
                    .allowsHitTesting(false)
            }

            SecretTouchSurface(
                longPressDuration: 0.6,
                resetDuration: 1.5,
                settingsGesture: settingsGesture,
                onTap: { point, touchCanvas in
                    controller.handleTap(at: point, in: touchCanvas)
                },
                onLongPress: {
                    controller.handleLongPress()
                },
                onTwoFingerLongPress: {
                    controller.handleResetGesture()
                },
                onSettingsGesture: {
                    controller.openSettings()
                },
                onCanvasChange: { newCanvas in
                    canvas = newCanvas
                }
            )
        }
        .ignoresSafeArea()
        .onChange(of: feedbackCount) { _, _ in
            flashIndicator()
        }
        .onDisappear {
            indicatorTask?.cancel()
        }
    }

    private func flashIndicator() {
        guard preferences.showsSecretIndicator else { return }
        indicatorTask?.cancel()
        indicatorVisible = true
        indicatorTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            indicatorVisible = false
        }
    }
}

/// Modo treino: desenha a grade invisível com os números (ou a contagem no modo B).
struct TrainingOverlay: View {
    let controller: TrickController
    let canvas: InputCanvas
    var rehearsalNumber: Int? = nil

    var body: some View {
        let mode = controller.configuration.inputMode
        let layout = controller.gridLayout(for: canvas)
        ZStack {
            if mode == .tapCount {
                Text(tapCountText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.35))
                    .position(x: canvas.size.width / 2, y: canvas.size.height / 2)
            } else {
                ForEach(layout.cells) { cell in
                    Rectangle()
                        .strokeBorder(Color(white: 0.25), lineWidth: 1)
                        .overlay(
                            Text("\(cell.digit)")
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(white: 0.35))
                        )
                        .frame(width: cell.rect.width, height: cell.rect.height)
                        .position(x: cell.rect.midX, y: cell.rect.midY)
                }
            }

            Text(statusText)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.45))
                .position(x: canvas.size.width / 2, y: canvas.safeAreaInsets.top + 20)
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
    }

    private var tapCountText: String {
        if case let .counting(count) = controller.secretInput.phase {
            return "\(count)"
        }
        return "0"
    }

    private var statusText: String {
        let prefix = rehearsalNumber.map { "ENSAIO · faça o \($0)" } ?? "TREINO"
        switch controller.secretInput.phase {
        case .empty:
            return prefix
        case let .counting(count):
            return "\(prefix) · \(count) toques"
        case let .tens(tens):
            return "\(prefix) · dezena \(tens)"
        case let .armed(value):
            return "\(prefix) · armado \(value)"
        }
    }
}
