import Foundation
import CoreGraphics

/// Modo de entrada secreta do número.
enum SecretInputMode: String, CaseIterable, Identifiable {
    /// Modo A: grade 3x3 (1 a 9).
    case grid
    /// Modo B: contagem de toques (1 a 30), confirmada com toque longo.
    case tapCount
    /// Modo C: grade em duas etapas, dezena + unidade (1 a 59).
    case twoStepGrid

    var id: String { rawValue }

    var validRange: ClosedRange<Int> {
        switch self {
        case .grid:
            return 1...9
        case .tapCount:
            return 1...30
        case .twoStepGrid:
            return 1...59
        }
    }
}

/// Insets de safe area sem depender de SwiftUI/UIKit (lógica pura).
struct CanvasInsets: Equatable, Sendable {
    var top: CGFloat = 0
    var leading: CGFloat = 0
    var bottom: CGFloat = 0
    var trailing: CGFloat = 0

    static let zero = CanvasInsets()
}

/// Área da tela onde os toques acontecem.
struct InputCanvas: Equatable, Sendable {
    var size: CGSize
    var safeAreaInsets: CanvasInsets

    init(size: CGSize, safeAreaInsets: CanvasInsets = .zero) {
        self.size = size
        self.safeAreaInsets = safeAreaInsets
    }
}

/// Uma célula da grade invisível (usada no modo treino para desenhar a grade).
struct SecretGridCell: Identifiable, Equatable {
    let digit: Int
    let rect: CGRect

    var id: Int { digit }
}

/// Mapeamento coordenada → dígito, com a numeração de teclado de telefone:
///
///     1 2 3
///     4 5 6
///     7 8 9
///       0     (só no modo C: centro de uma linha extra abaixo da grade)
struct SecretGridLayout: Equatable {
    static let defaultVerticalMargin: CGFloat = 40

    let mode: SecretInputMode
    let canvas: InputCanvas
    let verticalMargin: CGFloat

    init(mode: SecretInputMode, canvas: InputCanvas, verticalMargin: CGFloat = SecretGridLayout.defaultVerticalMargin) {
        self.mode = mode
        self.canvas = canvas
        self.verticalMargin = verticalMargin
    }

    /// Área útil: dentro das safe areas, ignorando `verticalMargin` no topo e embaixo.
    var activeArea: CGRect {
        let insets = canvas.safeAreaInsets
        let width = max(0, canvas.size.width - insets.leading - insets.trailing)
        let height = max(0, canvas.size.height - insets.top - insets.bottom - 2 * verticalMargin)
        return CGRect(x: insets.leading, y: insets.top + verticalMargin, width: width, height: height)
    }

    var hasZeroRow: Bool { mode == .twoStepGrid }

    var rowCount: Int { hasZeroRow ? 4 : 3 }

    /// Dígito sob o ponto, ou nil se o toque caiu fora da área útil (ou nas laterais da linha do zero).
    func digit(at point: CGPoint) -> Int? {
        let area = activeArea
        guard area.width > 0, area.height > 0, area.contains(point) else { return nil }
        let cellWidth = area.width / 3
        let cellHeight = area.height / CGFloat(rowCount)
        let column = min(2, max(0, Int((point.x - area.minX) / cellWidth)))
        let row = min(rowCount - 1, max(0, Int((point.y - area.minY) / cellHeight)))
        if row < 3 {
            return row * 3 + column + 1
        }
        return column == 1 ? 0 : nil
    }

    /// Retângulo da célula de um dígito (0 só existe no modo C).
    func rect(for digit: Int) -> CGRect? {
        let area = activeArea
        let cellWidth = area.width / 3
        let cellHeight = area.height / CGFloat(rowCount)
        if (1...9).contains(digit) {
            let index = digit - 1
            let column = index % 3
            let row = index / 3
            return CGRect(
                x: area.minX + CGFloat(column) * cellWidth,
                y: area.minY + CGFloat(row) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
        }
        if digit == 0 && hasZeroRow {
            return CGRect(x: area.minX + cellWidth, y: area.minY + 3 * cellHeight, width: cellWidth, height: cellHeight)
        }
        return nil
    }

    /// Todas as células válidas deste modo.
    var cells: [SecretGridCell] {
        let digits = hasZeroRow ? Array(1...9) + [0] : Array(1...9)
        return digits.compactMap { digit in
            rect(for: digit).map { SecretGridCell(digit: digit, rect: $0) }
        }
    }
}

/// Eventos que chegam da tela preta.
enum SecretInputEvent: Equatable {
    case tap(at: CGPoint, canvas: InputCanvas)
    case longPress
    case timeout
    case reset
}

/// Resultado de um evento, para o controller decidir transição e feedback.
enum SecretInputAction: Equatable {
    /// Nada aconteceu (toque ignorado).
    case none
    /// Modo B: toque contado (total até agora).
    case tapCounted(Int)
    /// Modo C: dígito da dezena registrado.
    case digitRegistered(Int)
    /// Número confirmado; continua preto aguardando o toque de "acordar".
    case armed(Int)
    /// Acender a tela de bloqueio com este offset.
    case wake(Int)
    /// Entrada inválida: haptic de erro e reset.
    case error
    /// Entrada zerada.
    case reset
}

/// Lógica pura da entrada secreta. Recebe eventos e devolve ações.
struct SecretInput: Equatable {
    enum Phase: Equatable {
        case empty
        /// Modo B: toques contados até agora.
        case counting(Int)
        /// Modo C: dezena escolhida, aguardando a unidade.
        case tens(Int)
        /// Número pronto; o próximo toque em qualquer lugar acende a tela.
        case armed(Int)
    }

    private(set) var mode: SecretInputMode
    var verticalMargin: CGFloat
    private(set) var phase: Phase = .empty

    init(mode: SecretInputMode = .grid, verticalMargin: CGFloat = SecretGridLayout.defaultVerticalMargin) {
        self.mode = mode
        self.verticalMargin = verticalMargin
    }

    /// Troca o modo e zera a entrada.
    mutating func setMode(_ newMode: SecretInputMode) {
        mode = newMode
        phase = .empty
    }

    var isEmpty: Bool { phase == .empty }

    /// Há uma entrada parcial que deve expirar por inatividade.
    var isPartial: Bool {
        switch phase {
        case .counting, .tens:
            return true
        case .empty, .armed:
            return false
        }
    }

    mutating func handle(_ event: SecretInputEvent) -> SecretInputAction {
        switch event {
        case .reset:
            phase = .empty
            return .reset
        case .timeout:
            guard isPartial else { return .none }
            phase = .empty
            return .reset
        case .longPress:
            return handleLongPress()
        case let .tap(point, canvas):
            return handleTap(at: point, canvas: canvas)
        }
    }

    private mutating func handleLongPress() -> SecretInputAction {
        guard mode == .tapCount else { return .none }
        if case let .counting(count) = phase, mode.validRange.contains(count) {
            phase = .empty
            return .wake(count)
        }
        phase = .empty
        return .error
    }

    private mutating func handleTap(at point: CGPoint, canvas: InputCanvas) -> SecretInputAction {
        if case let .armed(value) = phase {
            phase = .empty
            return .wake(value)
        }
        switch mode {
        case .tapCount:
            var count = 1
            if case let .counting(previous) = phase {
                count = previous + 1
            }
            phase = .counting(count)
            return .tapCounted(count)
        case .grid:
            let layout = SecretGridLayout(mode: mode, canvas: canvas, verticalMargin: verticalMargin)
            guard let digit = layout.digit(at: point), mode.validRange.contains(digit) else {
                return .none
            }
            phase = .armed(digit)
            return .armed(digit)
        case .twoStepGrid:
            let layout = SecretGridLayout(mode: mode, canvas: canvas, verticalMargin: verticalMargin)
            guard let digit = layout.digit(at: point) else {
                return .none
            }
            if case let .tens(tens) = phase {
                let value = tens * 10 + digit
                if mode.validRange.contains(value) {
                    phase = .armed(value)
                    return .armed(value)
                }
                phase = .empty
                return .error
            }
            guard digit <= 5 else {
                phase = .empty
                return .error
            }
            phase = .tens(digit)
            return .digitRegistered(digit)
        }
    }
}
