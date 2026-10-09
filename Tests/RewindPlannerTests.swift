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
}
