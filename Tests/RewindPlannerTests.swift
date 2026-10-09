import XCTest
@testable import TimeRewind

final class RewindPlannerTests: XCTestCase {
    private let calendar = TestSupport.calendar("America/Sao_Paulo")

    func testIntervalsSumToDurationAndArePositive() {
        for steps in [1, 2, 5, 8, 9, 30, 59] {
            let intervals = RewindPlanner.intervals(steps: steps, totalDuration: 3.5)
            XCTAssertEqual(intervals.count, steps)
            XCTAssertEqual(intervals.reduce(0, +), 3.5, accuracy: 0.0001, "N=\(steps)")
            XCTAssertTrue(intervals.allSatisfy { $0 > 0 }, "N=\(steps)")
        }
    }

    func testSingleStepRespectsMinimumDuration() {
        let intervals = RewindPlanner.intervals(steps: 1, totalDuration: 0.5)
        XCTAssertEqual(intervals.count, 1)
        XCTAssertEqual(intervals[0], 1.2, accuracy: 0.0001)
    }

    func testFiftyNineSteps() {
        let intervals = RewindPlanner.intervals(steps: 59, totalDuration: 3.5)
        XCTAssertEqual(intervals.count, 59)
        XCTAssertEqual(intervals.reduce(0, +), 3.5, accuracy: 0.0001)
        XCTAssertGreaterThan(intervals.min() ?? 0, 0.02)
    }

    func testEasingSlowFastSlow() {
        let intervals = RewindPlanner.intervals(steps: 9, totalDuration: 3.5)
        let middle = intervals[4]
        XCTAssertGreaterThan(intervals[0], middle)
        XCTAssertGreaterThan(intervals[8], middle)
        XCTAssertEqual(intervals[0], intervals[8], accuracy: 0.0001)
    }

    func testZeroStepsIsEmpty() {
        XCTAssertTrue(RewindPlanner.intervals(steps: 0, totalDuration: 3.5).isEmpty)
    }

    func testInvalidDurationFallsBack() {
        let intervals = RewindPlanner.intervals(steps: 3, totalDuration: .nan)
        XCTAssertEqual(intervals.reduce(0, +), RewindPlanner.defaultDuration, accuracy: 0.0001)
    }

    // MARK: - Progresso / alvo dinâmico

    func testProgressEndsExactlyAtRealTime() {
        let now = TestSupport.date(calendar, 2026, 10, 8, 14, 3, 20)
        let intervals = RewindPlanner.intervals(steps: 8, totalDuration: 3.5)
        var progress = RewindProgress(startedAt: now, offsetMinutes: 8, intervals: intervals, calendar: calendar)
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 14, 11))
        var elapsed: TimeInterval = 0
        while let interval = progress.nextInterval {
            elapsed += interval
            progress.advance(now: now.addingTimeInterval(elapsed), calendar: calendar)
        }
        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.completedSteps, 8)
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 14, 3))
    }

    func testDynamicTargetWhenMinuteTurnsDuringAnimation() {
        // Começa 14:03:58 com N=8 (mostra 14:11). O minuto real vira para 14:04 no meio.
        let start = TestSupport.date(calendar, 2026, 10, 8, 14, 3, 58)
        let intervals = RewindPlanner.intervals(steps: 8, totalDuration: 3.5)
        var progress = RewindProgress(startedAt: start, offsetMinutes: 8, intervals: intervals, calendar: calendar)
        var shown: [Date] = [progress.shownMinute]
        var elapsed: TimeInterval = 0
        var lastNow = start
        while let interval = progress.nextInterval {
            elapsed += interval
            lastNow = start.addingTimeInterval(elapsed)
            progress.advance(now: lastNow, calendar: calendar)
            shown.append(progress.shownMinute)
        }
        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.shownMinute, TimeEngine.truncatedToMinute(lastNow, calendar: calendar))
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 14, 4))
        // Sempre descendo de 1 em 1, sem repetir valores.
        for index in 1..<shown.count {
            XCTAssertEqual(shown[index - 1].timeIntervalSince(shown[index]), 60, accuracy: 0.001)
        }
        XCTAssertEqual(progress.completedSteps, 7)
    }

    func testDynamicTargetOnLastStep() {
        let start = TestSupport.date(calendar, 2026, 10, 8, 14, 3, 59)
        var progress = RewindProgress(startedAt: start, offsetMinutes: 1, intervals: [1.2], calendar: calendar)
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 14, 4))
        progress.advance(now: start.addingTimeInterval(1.2), calendar: calendar)
        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 14, 4))
    }

    func testSnapsToRealTimeWhenStepsRunOut() {
        // Relógio do sistema andou para trás: no último passo, ainda assim termina na hora real.
        let start = TestSupport.date(calendar, 2026, 10, 8, 14, 3, 0)
        var progress = RewindProgress(startedAt: start, offsetMinutes: 2, intervals: [0.5, 0.5], calendar: calendar)
        let earlier = TestSupport.date(calendar, 2026, 10, 8, 13, 50, 0)
        progress.advance(now: earlier, calendar: calendar)
        progress.advance(now: earlier, calendar: calendar)
        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 13, 50))
        XCTAssertNil(progress.nextInterval)
    }

    // MARK: - Ritmo fixo

    func testFixedRhythmIntervalsAreConstant() {
        for steps in [1, 8, 30, 59] {
            let intervals = RewindPlanner.intervals(steps: steps, pacing: .fixedRhythm, totalDuration: 3.5, secondsPerMinute: 2)
            XCTAssertEqual(intervals.count, steps)
            XCTAssertTrue(intervals.allSatisfy { abs($0 - 2) < 0.0001 }, "N=\(steps)")
            XCTAssertEqual(intervals.reduce(0, +), Double(steps) * 2, accuracy: 0.0001)
        }
    }

    func testFixedRhythmDefaultIsOneSecond() {
        XCTAssertEqual(RewindPlanner.defaultSecondsPerMinute, 1, accuracy: 0.0001)
        let intervals = RewindPlanner.fixedIntervals(steps: 3, secondsPerMinute: RewindPlanner.defaultSecondsPerMinute)
        XCTAssertEqual(intervals, [1, 1, 1])
    }

    func testFixedRhythmIsClampedToRange() {
        XCTAssertEqual(RewindPlanner.fixedIntervals(steps: 2, secondsPerMinute: 0.1), [0.5, 0.5])
        XCTAssertEqual(RewindPlanner.fixedIntervals(steps: 2, secondsPerMinute: 12), [5, 5])
        XCTAssertEqual(RewindPlanner.fixedIntervals(steps: 2, secondsPerMinute: .nan), [1, 1])
        XCTAssertTrue(RewindPlanner.fixedIntervals(steps: 0, secondsPerMinute: 1).isEmpty)
    }

    func testFixedRhythmIgnoresTotalDuration() {
        let short = RewindPlanner.intervals(steps: 5, pacing: .fixedRhythm, totalDuration: 1.2, secondsPerMinute: 1.5)
        let long = RewindPlanner.intervals(steps: 5, pacing: .fixedRhythm, totalDuration: 10, secondsPerMinute: 1.5)
        XCTAssertEqual(short, long)
    }

    // MARK: - Passo a passo

    func testStepByStepIsOneSecondPerMinute() {
        for steps in [1, 9, 59] {
            let intervals = RewindPlanner.intervals(steps: steps, pacing: .stepByStep, totalDuration: 3.5, secondsPerMinute: 4)
            XCTAssertEqual(intervals, Array(repeating: 1.0, count: steps), "N=\(steps)")
        }
    }

    func testTotalDurationPacingMatchesOriginalPlanner() {
        let viaPacing = RewindPlanner.intervals(steps: 8, pacing: .totalDuration, totalDuration: 3.5, secondsPerMinute: 2)
        XCTAssertEqual(viaPacing, RewindPlanner.intervals(steps: 8, totalDuration: 3.5))
    }

    // MARK: - Alvo dinâmico nos modos novos

    /// Simula o rewind com a hora real andando junto com os intervalos.
    private func run(_ progress: inout RewindProgress, start: Date) -> (shown: [Date], lastNow: Date) {
        var shown = [progress.shownMinute]
        var elapsed: TimeInterval = 0
        var lastNow = start
        while let interval = progress.nextInterval {
            elapsed += interval
            lastNow = start.addingTimeInterval(elapsed)
            progress.advance(now: lastNow, calendar: calendar)
            shown.append(progress.shownMinute)
        }
        return (shown, lastNow)
    }

    private func assertDescendsOneMinuteAtATime(_ shown: [Date], file: StaticString = #filePath, line: UInt = #line) {
        for index in 1..<shown.count {
            XCTAssertEqual(shown[index - 1].timeIntervalSince(shown[index]), 60, accuracy: 0.001, file: file, line: line)
        }
    }

    func testFixedRhythmDynamicTargetWhenMinuteTurns() {
        // 14:03:50, N=8, 5s por minuto: a hora real vira para 14:04 no 2º passo.
        let start = TestSupport.date(calendar, 2026, 10, 8, 14, 3, 50)
        let intervals = RewindPlanner.intervals(steps: 8, pacing: .fixedRhythm, totalDuration: 3.5, secondsPerMinute: 5)
        var progress = RewindProgress(startedAt: start, offsetMinutes: 8, intervals: intervals, calendar: calendar)
        let result = run(&progress, start: start)
        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.shownMinute, TimeEngine.truncatedToMinute(result.lastNow, calendar: calendar))
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 14, 4))
        XCTAssertEqual(progress.completedSteps, 7)
        assertDescendsOneMinuteAtATime(result.shown)
    }

    func testFixedRhythmSlowLongRewindCrossesSeveralMinutes() {
        // N=59 a 5s por minuto (~5 min de apresentação): o minuto real vira várias vezes.
        let start = TestSupport.date(calendar, 2026, 10, 8, 14, 3, 10)
        let intervals = RewindPlanner.intervals(steps: 59, pacing: .fixedRhythm, totalDuration: 3.5, secondsPerMinute: 5)
        var progress = RewindProgress(startedAt: start, offsetMinutes: 59, intervals: intervals, calendar: calendar)
        let result = run(&progress, start: start)
        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.shownMinute, TimeEngine.truncatedToMinute(result.lastNow, calendar: calendar))
        XCTAssertLessThan(progress.completedSteps, 59)
        assertDescendsOneMinuteAtATime(result.shown)
    }

    func testStepByStepDynamicTargetWhenMinuteTurns() {
        // 14:03:30, N=59, 1 por segundo: a hora real vira para 14:04 aos 30s.
        // Mostra 15:02 e precisa terminar em 14:04 → 58 passos, não 59.
        let start = TestSupport.date(calendar, 2026, 10, 8, 14, 3, 30)
        let intervals = RewindPlanner.intervals(steps: 59, pacing: .stepByStep, totalDuration: 3.5, secondsPerMinute: 1)
        var progress = RewindProgress(startedAt: start, offsetMinutes: 59, intervals: intervals, calendar: calendar)
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 15, 2))
        let result = run(&progress, start: start)
        XCTAssertTrue(progress.isFinished)
        XCTAssertEqual(progress.completedSteps, 58)
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 14, 4))
        XCTAssertEqual(progress.shownMinute, TimeEngine.truncatedToMinute(result.lastNow, calendar: calendar))
        assertDescendsOneMinuteAtATime(result.shown)
        XCTAssertNil(progress.nextInterval)
    }

    func testStepByStepWithoutMinuteTurnUsesAllSteps() {
        let start = TestSupport.date(calendar, 2026, 10, 8, 14, 3, 0)
        let intervals = RewindPlanner.intervals(steps: 9, pacing: .stepByStep, totalDuration: 3.5, secondsPerMinute: 1)
        var progress = RewindProgress(startedAt: start, offsetMinutes: 9, intervals: intervals, calendar: calendar)
        let result = run(&progress, start: start)
        XCTAssertEqual(progress.completedSteps, 9)
        XCTAssertEqual(progress.shownMinute, TestSupport.date(calendar, 2026, 10, 8, 14, 3))
        assertDescendsOneMinuteAtATime(result.shown)
    }

    func testPacingLabels() {
        XCTAssertEqual(RewindPacing.totalDuration.label, "Duração total")
        XCTAssertEqual(RewindPacing.fixedRhythm.label, "Ritmo fixo")
        XCTAssertEqual(RewindPacing.stepByStep.label, "Passo a passo")
    }
}
