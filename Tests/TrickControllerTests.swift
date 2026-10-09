import XCTest
import CoreGraphics
@testable import TimeRewind

/// Relógio controlável para os testes.
final class TestClock {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }
}

@MainActor
final class TrickControllerTests: XCTestCase {
    private let calendar = TestSupport.calendar("America/Sao_Paulo")
    private let canvas = TestSupport.devices[2].canvas

    private func makeController(
        mode: SecretInputMode = .grid,
        pacing: RewindPacing = .totalDuration,
        secondsPerMinute: TimeInterval = 1,
        clock: TestClock
    ) -> TrickController {
        var configuration = TrickConfiguration()
        configuration.inputMode = mode
        configuration.rewindPacing = pacing
        configuration.secondsPerMinute = secondsPerMinute
        configuration.rewindDuration = 1.2
        return TrickController(configuration: configuration, calendar: calendar, now: { clock.now })
    }

    func testGridFlowToLockScreen() async {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(clock: clock)
        XCTAssertEqual(controller.state, .dark)

        controller.handleTap(at: TestSupport.center(of: 8, canvas: canvas, rows: 3), in: canvas)
        XCTAssertEqual(controller.state, .armed(offset: 8))

        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        XCTAssertEqual(controller.state, .lockScreen(offset: 8))
        XCTAssertEqual(controller.displayedMinute(now: clock.now), TestSupport.date(calendar, 2026, 10, 8, 14, 11))
        XCTAssertEqual(controller.displayedMinute(now: clock.now.addingTimeInterval(120)), TestSupport.date(calendar, 2026, 10, 8, 14, 13))
    }

    func testTapCountFlow() async {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(mode: .tapCount, clock: clock)
        for _ in 1...3 {
            controller.handleTap(at: CGPoint(x: 100, y: 400), in: canvas)
        }
        XCTAssertEqual(controller.state, .dark)
        controller.handleLongPress()
        XCTAssertEqual(controller.state, .lockScreen(offset: 3))
    }

    func testFeedbackIsEmitted() async {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(clock: clock)
        var received: [TrickFeedback] = []
        controller.onFeedback = { received.append($0) }
        controller.handleTap(at: TestSupport.center(of: 4, canvas: canvas, rows: 3), in: canvas)
        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        XCTAssertEqual(received, [.armed(4), .wake])
    }

    func testResetGestureReturnsToDark() async {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(clock: clock)
        controller.handleTap(at: TestSupport.center(of: 2, canvas: canvas, rows: 3), in: canvas)
        controller.handleResetGesture()
        XCTAssertEqual(controller.state, .dark)
        XCTAssertTrue(controller.secretInput.isEmpty)
    }

    func testTapsIgnoredOutsideDarkStates() async {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(clock: clock)
        controller.handleTap(at: TestSupport.center(of: 5, canvas: canvas, rows: 3), in: canvas)
        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        controller.handleTap(at: TestSupport.center(of: 1, canvas: canvas, rows: 3), in: canvas)
        XCTAssertEqual(controller.state, .lockScreen(offset: 5))
    }

    func testSettingsOnlyFromDark() async {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(clock: clock)
        controller.handleTap(at: TestSupport.center(of: 5, canvas: canvas, rows: 3), in: canvas)
        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        controller.openSettings()
        XCTAssertEqual(controller.state, .lockScreen(offset: 5))
        controller.resetToDark()
        controller.openSettings()
        XCTAssertEqual(controller.state, .settings)
        controller.closeSettings()
        XCTAssertEqual(controller.state, .dark)
    }

    func testBackgroundReturnsToDark() async {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(clock: clock)
        controller.handleTap(at: TestSupport.center(of: 5, canvas: canvas, rows: 3), in: canvas)
        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        controller.sceneDidEnterBackground()
        XCTAssertEqual(controller.state, .dark)
    }

    func testRewindEndsLiveAtRealTime() async throws {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(clock: clock)
        controller.handleTap(at: TestSupport.center(of: 3, canvas: canvas, rows: 3), in: canvas)
        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        controller.triggerRewind()
        XCTAssertEqual(controller.state, .rewinding(from: 3))
        XCTAssertEqual(controller.displayedMinute(now: clock.now), TestSupport.date(calendar, 2026, 10, 8, 14, 6))

        var waited = 0
        while controller.state != .live && waited < 100 {
            try await Task.sleep(nanoseconds: 50_000_000)
            waited += 1
        }
        XCTAssertEqual(controller.state, .live)
        XCTAssertEqual(controller.displayedMinute(now: clock.now), TestSupport.date(calendar, 2026, 10, 8, 14, 3))
        XCTAssertNil(controller.rewindProgress)
    }

    func testDefaultPacingIsFixedRhythm() async {
        XCTAssertEqual(TrickConfiguration().rewindPacing, .fixedRhythm)
        XCTAssertEqual(TrickConfiguration().secondsPerMinute, 1, accuracy: 0.0001)
    }

    func testFixedRhythmRewindEndsLiveAtRealTime() async throws {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(pacing: .fixedRhythm, secondsPerMinute: 0.5, clock: clock)
        controller.handleTap(at: TestSupport.center(of: 2, canvas: canvas, rows: 3), in: canvas)
        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        controller.triggerRewind()
        XCTAssertEqual(controller.rewindProgress?.intervals, [0.5, 0.5])

        try await waitUntilLive(controller)
        XCTAssertEqual(controller.state, .live)
        XCTAssertEqual(controller.displayedMinute(now: clock.now), TestSupport.date(calendar, 2026, 10, 8, 14, 3))
    }

    func testStepByStepRewindEndsLiveAndIgnoresExtraTaps() async throws {
        let clock = TestClock(TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10))
        let controller = makeController(pacing: .stepByStep, secondsPerMinute: 4, clock: clock)
        var steps = 0
        controller.onFeedback = { feedback in
            if feedback == .rewindStep {
                steps += 1
            }
        }
        controller.handleTap(at: TestSupport.center(of: 2, canvas: canvas, rows: 3), in: canvas)
        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        controller.triggerRewind()
        // Passo a passo ignora o "segundos por minuto" do ritmo fixo: sempre 1s.
        XCTAssertEqual(controller.rewindProgress?.intervals, [1, 1])

        try await waitUntilLive(controller)
        XCTAssertEqual(controller.state, .live)
        XCTAssertEqual(steps, 1)
        XCTAssertEqual(controller.displayedMinute(now: clock.now), TestSupport.date(calendar, 2026, 10, 8, 14, 3))

        // Toques e gatilhos extras depois do fim não mudam nada.
        controller.handleTap(at: CGPoint(x: 10, y: 400), in: canvas)
        controller.triggerRewind()
        XCTAssertEqual(controller.state, .live)
        XCTAssertEqual(controller.displayedMinute(now: clock.now), TestSupport.date(calendar, 2026, 10, 8, 14, 3))
    }

    private func waitUntilLive(_ controller: TrickController, timeout: TimeInterval = 6) async throws {
        var waited: TimeInterval = 0
        while controller.state != .live && waited < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
            waited += 0.05
        }
    }
}
