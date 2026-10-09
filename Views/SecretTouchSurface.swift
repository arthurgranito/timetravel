import SwiftUI
import UIKit

/// Superfície invisível que captura os gestos da tela preta com UIKit
/// (toque com coordenada, toque longo de 1 dedo e toque longo de 2 dedos),
/// usando as safe areas reais da janela.
struct SecretTouchSurface: UIViewRepresentable {
    var longPressDuration: TimeInterval = 0.6
    var resetDuration: TimeInterval = 1.5
    var onTap: @MainActor (CGPoint, InputCanvas) -> Void
    var onLongPress: @MainActor () -> Void
    var onTwoFingerLongPress: @MainActor () -> Void
    var onCanvasChange: @MainActor (InputCanvas) -> Void

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

        let twoFingerLongPress = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTwoFingerLongPress(_:)))
        twoFingerLongPress.numberOfTouchesRequired = 2
        twoFingerLongPress.minimumPressDuration = resetDuration

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTouchesRequired = 1
        tap.numberOfTapsRequired = 1
        tap.require(toFail: longPress)

        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
        view.addGestureRecognizer(twoFingerLongPress)
        coordinator.longPress = longPress
        coordinator.twoFingerLongPress = twoFingerLongPress
        return view
    }

    func updateUIView(_ uiView: TouchSurfaceView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.longPress?.minimumPressDuration = longPressDuration
        context.coordinator.twoFingerLongPress?.minimumPressDuration = resetDuration
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: SecretTouchSurface
        weak var longPress: UILongPressGestureRecognizer?
        weak var twoFingerLongPress: UILongPressGestureRecognizer?
        private var lastCanvas: InputCanvas?

        init(parent: SecretTouchSurface) {
            self.parent = parent
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
            parent.onTwoFingerLongPress()
        }

        func reportCanvas(_ canvas: InputCanvas) {
            guard canvas != lastCanvas, canvas.size.width > 0, canvas.size.height > 0 else { return }
            lastCanvas = canvas
            // Fora do ciclo de layout, para não alterar estado do SwiftUI durante uma atualização.
            Task { @MainActor [weak self] in
                self?.parent.onCanvasChange(canvas)
            }
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
