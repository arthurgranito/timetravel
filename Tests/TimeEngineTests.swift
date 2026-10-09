import XCTest
@testable import TimeRewind

final class TimeEngineTests: XCTestCase {
    private let saoPaulo = TestSupport.calendar("America/Sao_Paulo")
    private let newYork = TestSupport.calendar("America/New_York")
    private let h24 = ClockFormatOptions(uses24Hour: true, leadingZeroHour: true)

    private func time(_ date: Date, _ calendar: Calendar) -> String {
        TimeEngine.timeString(for: date, calendar: calendar, options: h24)
    }

    private func dateText(_ date: Date, _ calendar: Calendar, capitalize: Bool = false) -> String {
        TimeEngine.dateString(
            for: date,
            calendar: calendar,
            options: DateFormatOptions(capitalizeFirstLetter: capitalize)
        )
    }

    /// Simula um rewind completo com a hora real parada e devolve cada minuto mostrado.
    private func rewindSequence(now: Date, offset: Int, calendar: Calendar) -> [Date] {
        let intervals = RewindPlanner.intervals(steps: offset, totalDuration: 3.5)
        var progress = RewindProgress(startedAt: now, offsetMinutes: offset, intervals: intervals, calendar: calendar)
        var shown = [progress.shownMinute]
        while progress.nextInterval != nil {
            progress.advance(now: now, calendar: calendar)
            shown.append(progress.shownMinute)
        }
        return shown
    }

    // MARK: - Básico

    func testDisplayedDateAddsOffsetMinutes() {
        let now = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 3, 25)
        let shown = TimeEngine.displayedDate(now: now, offsetMinutes: 8)
        XCTAssertEqual(shown.timeIntervalSince(now), 480, accuracy: 0.0001)
    }

    func testTruncatesToMinute() {
        let now = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 3, 59, nanosecond: 900_000_000)
        let truncated = TimeEngine.truncatedToMinute(now, calendar: saoPaulo)
        XCTAssertEqual(truncated, TestSupport.date(saoPaulo, 2026, 10, 8, 14, 3, 0))
        XCTAssertEqual(time(now, saoPaulo), "14:03")
    }

    func testNextMinuteBoundary() {
        let now = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 3, 12)
        let next = TimeEngine.nextMinuteBoundary(after: now, calendar: saoPaulo)
        XCTAssertEqual(next, TestSupport.date(saoPaulo, 2026, 10, 8, 14, 4, 0))
        let exact = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 4, 0)
        XCTAssertEqual(TimeEngine.nextMinuteBoundary(after: exact, calendar: saoPaulo), TestSupport.date(saoPaulo, 2026, 10, 8, 14, 5, 0))
    }

    func testClockKeepsRunningWhileShowingOffset() {
        let start = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 3, 10)
        let twoMinutesLater = start.addingTimeInterval(120)
        XCTAssertEqual(time(TimeEngine.displayedMinute(now: start, offsetMinutes: 8, calendar: saoPaulo), saoPaulo), "14:11")
        XCTAssertEqual(time(TimeEngine.displayedMinute(now: twoMinutesLater, offsetMinutes: 8, calendar: saoPaulo), saoPaulo), "14:13")
    }

    // MARK: - Viradas

    func testHourRollover() {
        let now = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 3, 30)
        let sequence = rewindSequence(now: now, offset: 8, calendar: saoPaulo).map { time($0, saoPaulo) }
        XCTAssertEqual(sequence, ["14:11", "14:10", "14:09", "14:08", "14:07", "14:06", "14:05", "14:04", "14:03"])
    }

    func testHourRolloverBackwards() {
        let now = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 58, 0)
        let sequence = rewindSequence(now: now, offset: 5, calendar: saoPaulo).map { time($0, saoPaulo) }
        XCTAssertEqual(sequence, ["15:03", "15:02", "15:01", "15:00", "14:59", "14:58"])
    }

    func testDayRolloverChangesDate() {
        let now = TestSupport.date(saoPaulo, 2026, 10, 8, 23, 57, 0)
        let shown = TimeEngine.displayedMinute(now: now, offsetMinutes: 6, calendar: saoPaulo)
        XCTAssertEqual(time(shown, saoPaulo), "00:03")
        XCTAssertEqual(saoPaulo.component(.day, from: shown), 9)
        XCTAssertEqual(dateText(shown, saoPaulo), "sexta-feira, 9 de outubro")

        let sequence = rewindSequence(now: now, offset: 6, calendar: saoPaulo)
        XCTAssertEqual(sequence.map { time($0, saoPaulo) }, ["00:03", "00:02", "00:01", "00:00", "23:59", "23:58", "23:57"])
        XCTAssertEqual(sequence.map { saoPaulo.component(.day, from: $0) }, [9, 9, 9, 9, 8, 8, 8])
        XCTAssertEqual(dateText(sequence.last!, saoPaulo), "quinta-feira, 8 de outubro")
    }

    func testMonthRollover() {
        let now = TestSupport.date(saoPaulo, 2026, 2, 28, 23, 58, 0)
        let shown = TimeEngine.displayedMinute(now: now, offsetMinutes: 5, calendar: saoPaulo)
        XCTAssertEqual(time(shown, saoPaulo), "00:03")
        XCTAssertEqual(saoPaulo.component(.month, from: shown), 3)
        XCTAssertEqual(saoPaulo.component(.day, from: shown), 1)
        let last = rewindSequence(now: now, offset: 5, calendar: saoPaulo).last!
        XCTAssertEqual(saoPaulo.component(.month, from: last), 2)
        XCTAssertEqual(saoPaulo.component(.day, from: last), 28)
    }

    func testYearRollover() {
        let now = TestSupport.date(saoPaulo, 2026, 12, 31, 23, 59, 0)
        let shown = TimeEngine.displayedMinute(now: now, offsetMinutes: 1, calendar: saoPaulo)
        XCTAssertEqual(time(shown, saoPaulo), "00:00")
        XCTAssertEqual(saoPaulo.component(.year, from: shown), 2027)
        XCTAssertEqual(dateText(shown, saoPaulo), "sexta-feira, 1 de janeiro")
        let last = rewindSequence(now: now, offset: 1, calendar: saoPaulo).last!
        XCTAssertEqual(saoPaulo.component(.year, from: last), 2026)
        XCTAssertEqual(time(last, saoPaulo), "23:59")
        XCTAssertEqual(dateText(last, saoPaulo), "quinta-feira, 31 de dezembro")
    }

    // MARK: - Horário de verão

    func testDaylightSavingSpringForward() {
        // 10/03/2024: em Nova York 02:00 vira 03:00.
        let now = TestSupport.date(newYork, 2024, 3, 10, 1, 58, 0)
        let shown = TimeEngine.displayedMinute(now: now, offsetMinutes: 5, calendar: newYork)
        XCTAssertEqual(time(shown, newYork), "03:03")
        let sequence = rewindSequence(now: now, offset: 5, calendar: newYork).map { time($0, newYork) }
        XCTAssertEqual(sequence, ["03:03", "03:02", "03:01", "03:00", "01:59", "01:58"])
    }

    func testDaylightSavingFallBack() {
        // 03/11/2024: em Nova York 02:00 (EDT) vira 01:00 (EST). 05:58 UTC = 01:58 EDT.
        let now = TestSupport.utc(2024, 11, 3, 5, 58)
        XCTAssertEqual(time(now, newYork), "01:58")
        let shown = TimeEngine.displayedMinute(now: now, offsetMinutes: 5, calendar: newYork)
        XCTAssertEqual(time(shown, newYork), "01:03")
        let sequence = rewindSequence(now: now, offset: 5, calendar: newYork)
        XCTAssertEqual(sequence.map { time($0, newYork) }, ["01:03", "01:02", "01:01", "01:00", "01:59", "01:58"])
        XCTAssertEqual(sequence.last, now)
    }

    // MARK: - Formatação

    func testFormat24hWithAndWithoutLeadingZero() {
        let morning = TestSupport.date(saoPaulo, 2026, 10, 8, 9, 41, 0)
        XCTAssertEqual(TimeEngine.timeString(for: morning, calendar: saoPaulo, options: ClockFormatOptions(uses24Hour: true, leadingZeroHour: true)), "09:41")
        XCTAssertEqual(TimeEngine.timeString(for: morning, calendar: saoPaulo, options: ClockFormatOptions(uses24Hour: true, leadingZeroHour: false)), "9:41")
        let midnight = TestSupport.date(saoPaulo, 2026, 10, 8, 0, 5, 0)
        XCTAssertEqual(TimeEngine.timeString(for: midnight, calendar: saoPaulo, options: ClockFormatOptions(uses24Hour: true, leadingZeroHour: true)), "00:05")
    }

    func testFormat12h() {
        let options = ClockFormatOptions(uses24Hour: false, leadingZeroHour: false)
        let afternoon = TestSupport.date(saoPaulo, 2026, 10, 8, 13, 5, 0)
        let midnight = TestSupport.date(saoPaulo, 2026, 10, 8, 0, 7, 0)
        let noon = TestSupport.date(saoPaulo, 2026, 10, 8, 12, 0, 0)
        XCTAssertEqual(TimeEngine.timeString(for: afternoon, calendar: saoPaulo, options: options), "1:05")
        XCTAssertEqual(TimeEngine.timeString(for: midnight, calendar: saoPaulo, options: options), "12:07")
        XCTAssertEqual(TimeEngine.timeString(for: noon, calendar: saoPaulo, options: options), "12:00")
        XCTAssertEqual(TimeEngine.timeString(for: afternoon, calendar: saoPaulo, options: ClockFormatOptions(uses24Hour: false, leadingZeroHour: true)), "01:05")
    }

    func testDatePtBR() {
        let date = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 3, 0)
        XCTAssertEqual(dateText(date, saoPaulo), "quinta-feira, 8 de outubro")
        XCTAssertEqual(dateText(date, saoPaulo, capitalize: true), "Quinta-feira, 8 de outubro")
    }

    func testCustomDateFormat() {
        let date = TestSupport.date(saoPaulo, 2026, 10, 8, 14, 3, 0)
        let options = DateFormatOptions(format: "d/MM", localeIdentifier: "pt_BR", capitalizeFirstLetter: false)
        XCTAssertEqual(TimeEngine.dateString(for: date, calendar: saoPaulo, options: options), "8/10")
    }

    func testFormatterIsCached() {
        let first = DateFormatterCache.shared.formatter(format: "EEEE", localeIdentifier: "pt_BR", calendar: saoPaulo)
        let second = DateFormatterCache.shared.formatter(format: "EEEE", localeIdentifier: "pt_BR", calendar: saoPaulo)
        XCTAssertTrue(first === second)
    }
}
