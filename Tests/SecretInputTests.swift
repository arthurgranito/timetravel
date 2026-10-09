import XCTest
import CoreGraphics
@testable import TimeRewind

final class SecretInputTests: XCTestCase {
    private let iPhone15 = TestSupport.devices[2].canvas

    private func tap(_ input: inout SecretInput, digit: Int, canvas: InputCanvas) -> SecretInputAction {
        let rows = input.mode == .twoStepGrid ? 4 : 3
        let point = TestSupport.center(of: digit, canvas: canvas, rows: rows)
        return input.handle(.tap(at: point, canvas: canvas))
    }

    private func tapAnywhere(_ input: inout SecretInput, canvas: InputCanvas) -> SecretInputAction {
        input.handle(.tap(at: CGPoint(x: canvas.size.width / 2, y: canvas.size.height / 2), canvas: canvas))
    }

    // MARK: - Mapeamento da grade

    func testGridMappingOnAllDevices() {
        for device in TestSupport.devices {
            let layout = SecretGridLayout(mode: .grid, canvas: device.canvas)
            for digit in 1...9 {
                let point = TestSupport.center(of: digit, canvas: device.canvas, rows: 3)
                XCTAssertEqual(layout.digit(at: point), digit, "\(device.name) dígito \(digit)")
                XCTAssertEqual(layout.rect(for: digit)?.contains(point), true, "\(device.name) rect \(digit)")
            }
            XCTAssertNil(layout.rect(for: 0), device.name)
            XCTAssertEqual(layout.cells.count, 9, device.name)
        }
    }

    func testGridCornersOnAllDevices() {
        for device in TestSupport.devices {
            let canvas = device.canvas
            let layout = SecretGridLayout(mode: .grid, canvas: canvas)
            let area = layout.activeArea
            XCTAssertEqual(layout.digit(at: CGPoint(x: area.minX + 1, y: area.minY + 1)), 1, device.name)
            XCTAssertEqual(layout.digit(at: CGPoint(x: area.maxX - 1, y: area.minY + 1)), 3, device.name)
            XCTAssertEqual(layout.digit(at: CGPoint(x: area.minX + 1, y: area.maxY - 1)), 7, device.name)
            XCTAssertEqual(layout.digit(at: CGPoint(x: area.maxX - 1, y: area.maxY - 1)), 9, device.name)
        }
    }

    func testMarginsAreIgnored() {
        for device in TestSupport.devices {
            let canvas = device.canvas
            let layout = SecretGridLayout(mode: .grid, canvas: canvas)
            let topMarginY = canvas.safeAreaInsets.top + 20
            let bottomMarginY = canvas.size.height - canvas.safeAreaInsets.bottom - 20
            XCTAssertNil(layout.digit(at: CGPoint(x: canvas.size.width / 2, y: topMarginY)), device.name)
            XCTAssertNil(layout.digit(at: CGPoint(x: canvas.size.width / 2, y: bottomMarginY)), device.name)
            XCTAssertNil(layout.digit(at: CGPoint(x: canvas.size.width / 2, y: 2)), device.name)
            XCTAssertNil(layout.digit(at: CGPoint(x: canvas.size.width / 2, y: canvas.size.height - 2)), device.name)
            XCTAssertEqual(layout.activeArea.minY, canvas.safeAreaInsets.top + 40, accuracy: 0.001)
        }
    }

    func testTwoStepGridMappingIncludesZero() {
        for device in TestSupport.devices {
            let layout = SecretGridLayout(mode: .twoStepGrid, canvas: device.canvas)
            for digit in 0...9 {
                let point = TestSupport.center(of: digit, canvas: device.canvas, rows: 4)
                XCTAssertEqual(layout.digit(at: point), digit, "\(device.name) dígito \(digit)")
            }
            let zeroRect = layout.rect(for: 0)!
            XCTAssertNil(layout.digit(at: CGPoint(x: zeroRect.minX - 10, y: zeroRect.midY)), device.name)
            XCTAssertNil(layout.digit(at: CGPoint(x: zeroRect.maxX + 10, y: zeroRect.midY)), device.name)
            XCTAssertEqual(layout.cells.count, 10, device.name)
        }
    }

    // MARK: - Modo A

    func testModeAFlow() {
        for device in TestSupport.devices {
            var input = SecretInput(mode: .grid)
            XCTAssertEqual(tap(&input, digit: 8, canvas: device.canvas), .armed(8), device.name)
            XCTAssertEqual(input.phase, .armed(8))
            XCTAssertEqual(tapAnywhere(&input, canvas: device.canvas), .wake(8), device.name)
            XCTAssertEqual(input.phase, .empty)
        }
    }

    func testModeAEveryDigit() {
        for digit in 1...9 {
            var input = SecretInput(mode: .grid)
            XCTAssertEqual(tap(&input, digit: digit, canvas: iPhone15), .armed(digit))
            XCTAssertEqual(tapAnywhere(&input, canvas: iPhone15), .wake(digit))
        }
    }

    func testModeAIgnoresMarginTapAndLongPress() {
        var input = SecretInput(mode: .grid)
        let action = input.handle(.tap(at: CGPoint(x: 100, y: iPhone15.safeAreaInsets.top + 10), canvas: iPhone15))
        XCTAssertEqual(action, .none)
        XCTAssertEqual(input.phase, .empty)
        XCTAssertEqual(input.handle(.longPress), .none)
        XCTAssertEqual(input.handle(.timeout), .none)
    }

    // MARK: - Modo B

    func testModeBCountsAndConfirms() {
        var input = SecretInput(mode: .tapCount)
        for expected in 1...12 {
            XCTAssertEqual(tapAnywhere(&input, canvas: iPhone15), .tapCounted(expected))
        }
        XCTAssertEqual(input.handle(.longPress), .wake(12))
        XCTAssertEqual(input.phase, .empty)
    }

    func testModeBMaximum() {
        var input = SecretInput(mode: .tapCount)
        for _ in 1...30 {
            _ = tapAnywhere(&input, canvas: iPhone15)
        }
        XCTAssertEqual(input.handle(.longPress), .wake(30))
    }

    func testModeBTooManyTapsIsError() {
        var input = SecretInput(mode: .tapCount)
        for _ in 1...31 {
            _ = tapAnywhere(&input, canvas: iPhone15)
        }
        XCTAssertEqual(input.handle(.longPress), .error)
        XCTAssertEqual(input.phase, .empty)
    }

    func testModeBLongPressWithoutTapsIsError() {
        var input = SecretInput(mode: .tapCount)
        XCTAssertEqual(input.handle(.longPress), .error)
    }

    func testModeBTimeoutResetsCount() {
        var input = SecretInput(mode: .tapCount)
        _ = tapAnywhere(&input, canvas: iPhone15)
        _ = tapAnywhere(&input, canvas: iPhone15)
        XCTAssertTrue(input.isPartial)
        XCTAssertEqual(input.handle(.timeout), .reset)
        XCTAssertEqual(input.phase, .empty)
        XCTAssertEqual(tapAnywhere(&input, canvas: iPhone15), .tapCounted(1))
    }

    // MARK: - Modo C

    func testModeCValidNumbers() {
        let cases: [(Int, Int, Int)] = [(0, 1, 1), (0, 8, 8), (1, 0, 10), (2, 7, 27), (4, 5, 45), (5, 9, 59)]
        for (tens, units, expected) in cases {
            var input = SecretInput(mode: .twoStepGrid)
            XCTAssertEqual(tap(&input, digit: tens, canvas: iPhone15), .digitRegistered(tens))
            XCTAssertEqual(tap(&input, digit: units, canvas: iPhone15), .armed(expected))
            XCTAssertEqual(tapAnywhere(&input, canvas: iPhone15), .wake(expected))
        }
    }

    func testModeCZeroZeroIsError() {
        var input = SecretInput(mode: .twoStepGrid)
        XCTAssertEqual(tap(&input, digit: 0, canvas: iPhone15), .digitRegistered(0))
        XCTAssertEqual(tap(&input, digit: 0, canvas: iPhone15), .error)
        XCTAssertEqual(input.phase, .empty)
    }

    func testModeCInvalidTensIsError() {
        for tens in 6...9 {
            var input = SecretInput(mode: .twoStepGrid)
            XCTAssertEqual(tap(&input, digit: tens, canvas: iPhone15), .error)
            XCTAssertEqual(input.phase, .empty)
        }
    }

    func testModeCTimeoutAndReset() {
        var input = SecretInput(mode: .twoStepGrid)
        _ = tap(&input, digit: 3, canvas: iPhone15)
        XCTAssertEqual(input.handle(.timeout), .reset)
        XCTAssertEqual(input.phase, .empty)

        _ = tap(&input, digit: 3, canvas: iPhone15)
        _ = tap(&input, digit: 2, canvas: iPhone15)
        XCTAssertEqual(input.phase, .armed(32))
        XCTAssertEqual(input.handle(.timeout), .none)
        XCTAssertEqual(input.handle(.reset), .reset)
        XCTAssertEqual(input.phase, .empty)
    }

    // MARK: - Comuns

    func testResetFromAnyPhase() {
        var input = SecretInput(mode: .grid)
        _ = tap(&input, digit: 5, canvas: iPhone15)
        XCTAssertEqual(input.handle(.reset), .reset)
        XCTAssertEqual(input.phase, .empty)
    }

    func testChangingModeClearsInput() {
        var input = SecretInput(mode: .grid)
        _ = tap(&input, digit: 5, canvas: iPhone15)
        input.setMode(.tapCount)
        XCTAssertEqual(input.phase, .empty)
        XCTAssertEqual(input.mode, .tapCount)
    }

    func testValidRanges() {
        XCTAssertEqual(SecretInputMode.grid.validRange, 1...9)
        XCTAssertEqual(SecretInputMode.tapCount.validRange, 1...30)
        XCTAssertEqual(SecretInputMode.twoStepGrid.validRange, 1...59)
    }
}
