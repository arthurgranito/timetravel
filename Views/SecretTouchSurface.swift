import SwiftUI
import UIKit

/// Superfície invisível que captura os gestos da tela preta com UIKit
/// (toque com coordenada, toque longo de 1 dedo, toque longo de 2 dedos e o gesto
/// secreto das configurações), usando as safe areas reais da janela.
struct SecretTouchSurface: UIViewRepresentable {
    var longPressDuration: TimeInterval = 0.6
    var resetDuration: TimeInterval = 1.5
    var settingsGesture: SettingsGesture = .threeTwoFingerTaps
    var onTap: @MainActor (CGPoint, InputCanvas) -> Void
    var onLongPress: @MainActor () -> Void
    var onTwoFingerLongPress: @MainActor () -> Void
    var onSettingsGesture: @MainActor () -> Void
    var onCanvasChange: @MainActor (InputCanvas) -> Void

    /// Tamanho (pt) do canto superior esquerdo que aceita o toque longo de 3s.
    static let cornerSize: CGFloat = 100
    /// Janela de tempo para os três toques com dois dedos.
    static let twoFingerTapWindow: TimeInterval = 1.5

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> TouchSurfaceView {
        let view = TouchSurfaceView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        let coordinator = context.coordinator
        view.onLayout = { [weak coordinator] canvas in
            coordinator?.reportCanvas(canvas)
        }

        let longPress = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.numberOfTouchesRequired = 1
        longPress.minimumPressDuration = longPressDuration

        let cornerLongPress = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleCornerLongPress(_:)))
        cornerLongPress.numberOfTouchesRequired = 1
        cornerLongPress.minimumPressDuration = 3
        cornerLongPress.delegate = coordinator

        let twoFingerLongPress = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTwoFingerLongPress(_:)))
        twoFingerLongPress.numberOfTouchesRequired = 2
        twoFingerLongPress.minimumPressDuration = resetDuration

        let twoFingerTap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.numberOfTapsRequired = 1

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTouchesRequired = 1
        tap.numberOfTapsRequired = 1
        tap.require(toFail: longPress)

        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
        view.addGestureRecognizer(cornerLongPress)
        view.addGestureRecognizer(twoFingerLongPress)
        view.addGestureRecognizer(twoFingerTap)
        coordinator.longPress = longPress
        coordinator.cornerLongPress = cornerLongPress
        coordinator.twoFingerLongPress = twoFingerLongPress
        coordinator.twoFingerTap = twoFingerTap
        coordinator.applyGestureSettings()
        return view
    }

    func updateUIView(_ uiView: TouchSurfaceView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyGestureSettings()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: SecretTouchSurface
        weak var longPress: UILongPressGestureRecognizer?
        weak var cornerLongPress: UILongPressGestureRecognizer?
        weak var twoFingerLongPress: UILongPressGestureRecognizer?
        weak var twoFingerTap: UITapGestureRecognizer?
        private var lastCanvas: InputCanvas?
        private var twoFingerTapTimes: [Date] = []

        init(parent: SecretTouchSurface) {
            self.parent = parent
        }

        func applyGestureSettings() {
            longPress?.minimumPressDuration = parent.longPressDuration
            twoFingerLongPress?.minimumPressDuration = parent.resetDuration
            cornerLongPress?.isEnabled = parent.settingsGesture == .cornerLongPress
            twoFingerTap?.isEnabled = parent.settingsGesture == .threeTwoFingerTaps
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view as? TouchSurfaceView else { return }
            parent.onTap(recognizer.location(in: view), view.canvas)
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            parent.onLongPress()
        }

        @objc func handleTwoFingerLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            twoFingerTapTimes.removeAll()
            parent.onTwoFingerLongPress()
        }

        @objc func handleTwoFingerTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            let now = Date()
            twoFingerTapTimes = twoFingerTapTimes.filter { now.timeIntervalSince($0) <= SecretTouchSurface.twoFingerTapWindow }
            twoFingerTapTimes.append(now)
            if twoFingerTapTimes.count >= 3 {
                twoFingerTapTimes.removeAll()
                parent.onSettingsGesture()
            }
        }

        @objc func handleCornerLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let view = recognizer.view else { return }
            let point = recognizer.location(in: view)
            let limit = SecretTouchSurface.cornerSize
            guard point.x <= limit, point.y <= view.safeAreaInsets.top + limit else { return }
            parent.onSettingsGesture()
        }

        func reportCanvas(_ canvas: InputCanvas) {
            guard canvas != lastCanvas, canvas.size.width > 0, canvas.size.height > 0 else { return }
            lastCanvas = canvas
            // Fora do ciclo de layout, para não alterar estado do SwiftUI durante uma atualização.
            Task { @MainActor [weak self] in
                self?.parent.onCanvasChange(canvas)
            }
        }

        /// O toque longo de 3s do canto convive com o toque longo de 0,6s do modo B.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            gestureRecognizer === cornerLongPress || otherGestureRecognizer === cornerLongPress
        }
    }
}

/// UIView que informa tamanho e safe areas sempre que o layout muda.
final class TouchSurfaceView: UIView {
    var onLayout: (@MainActor (InputCanvas) -> Void)?

    var canvas: InputCanvas {
        InputCanvas(
            size: bounds.size,
            safeAreaInsets: CanvasInsets(
                top: safeAreaInsets.top,
                leading: safeAreaInsets.left,
                bottom: safeAreaInsets.bottom,
                trailing: safeAreaInsets.right
            )
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(canvas)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onLayout?(canvas)
    }
}
