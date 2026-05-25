import XCTest
@testable import OnCue

final class ICSParserTests: XCTestCase {
    func testParsesSingleTimedEvent() throws {
        let text = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:event-1
        SUMMARY:Design Review
        DTSTART:20260525T100000Z
        DTEND:20260525T103000Z
        END:VEVENT
        END:VCALENDAR
        """

        let events = ICSParser.parse(
            text: text,
            window: DateInterval(start: try date("20260525T090000Z"), end: try date("20260525T110000Z")),
            calendarName: "Work"
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.id, "ics-event-1")
        XCTAssertEqual(events.first?.title, "Design Review")
        XCTAssertEqual(events.first?.calendarName, "Work")
        XCTAssertEqual(events.first?.startDate, try date("20260525T100000Z"))
        XCTAssertEqual(events.first?.endDate, try date("20260525T103000Z"))
    }

    func testExpandsWeeklyByDayRecurrenceWithCount() throws {
        let text = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:weekly-1
        SUMMARY:Standup
        DTSTART:20260525T100000Z
        DTEND:20260525T101500Z
        RRULE:FREQ=WEEKLY;COUNT=4;BYDAY=MO,WE
        END:VEVENT
        END:VCALENDAR
        """

        let events = ICSParser.parse(
            text: text,
            window: DateInterval(start: try date("20260524T000000Z"), end: try date("20260604T000000Z")),
            calendarName: "Team"
        )

        XCTAssertEqual(events.map(\.startDate), [
            try date("20260525T100000Z"),
            try date("20260527T100000Z"),
            try date("20260601T100000Z"),
            try date("20260603T100000Z")
        ])
    }

    func testUnescapesSummaryAndUsesDurationFallback() throws {
        let text = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:duration-1
        SUMMARY:Planning\\, notes\\nSecond line
        DTSTART:20260525T120000Z
        DURATION:PT45M
        END:VEVENT
        END:VCALENDAR
        """

        let events = ICSParser.parse(
            text: text,
            window: DateInterval(start: try date("20260525T110000Z"), end: try date("20260525T130000Z")),
            calendarName: "Planning"
        )

        XCTAssertEqual(events.first?.title, "Planning, notes\nSecond line")
        XCTAssertEqual(events.first?.endDate, try date("20260525T124500Z"))
    }

    func testSkipsAllDayEvents() throws {
        let text = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:all-day-1
        SUMMARY:Company offsite
        DTSTART;VALUE=DATE:20260525
        DTEND;VALUE=DATE:20260526
        END:VEVENT
        END:VCALENDAR
        """

        let events = ICSParser.parse(
            text: text,
            window: DateInterval(start: try date("20260524T000000Z"), end: try date("20260527T000000Z")),
            calendarName: "Holidays"
        )

        XCTAssertTrue(events.isEmpty)
    }

    private func date(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return try XCTUnwrap(formatter.date(from: value))
    }
}
