import SwiftUI
import UIKit

/// Tamanho da tela inteira e safe areas, para posicionar tudo de forma relativa.
struct ScreenMetrics: Equatable {
    var size: CGSize
    var safeTop: CGFloat
    var safeBottom: CGFloat
    var safeLeading: CGFloat
    var safeTrailing: CGFloat

    init(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat, safeLeading: CGFloat = 0, safeTrailing: CGFloat = 0) {
        self.size = size
        self.safeTop = safeTop
        self.safeBottom = safeBottom
        self.safeLeading = safeLeading
        self.safeTrailing = safeTrailing
    }

    /// `proxy` deve vir de um GeometryReader que ignora as safe areas (tela inteira).
    /// As insets do proxy são combinadas com as da janela, por segurança.
    @MainActor
    init(proxy: GeometryProxy) {
        let insets = proxy.safeAreaInsets
        let window = ScreenMetrics.windowSafeAreaInsets()
        self.init(
            size: proxy.size,
            safeTop: max(insets.top, window.top),
            safeBottom: max(insets.bottom, window.bottom),
            safeLeading: max(insets.leading, window.left),
            safeTrailing: max(insets.trailing, window.right)
        )
    }

    /// iPhone com botão Home (SE): sem área segura embaixo.
    var hasHomeButton: Bool { safeBottom < 1 }

    /// iPhone com Dynamic Island (safe area de topo maior que a do notch).
    var hasDynamicIsland: Bool { safeTop >= 51 }

    @MainActor
    static func windowSafeAreaInsets() -> UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let window = windows.first { $0.isKeyWindow } ?? windows.first
        return window?.safeAreaInsets ?? .zero
    }
}
