import SwiftUI

/// Fase 1: apenas a tela preta pura (#000000), que no OLED parece a tela desligada.
struct RootView: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
            .statusBarHidden(true)
            .preferredColorScheme(.dark)
            .defersSystemGestures(on: .bottom)
    }
}
