import XCTest
@testable import OnCue

@MainActor
final class EventStoreTests: XCTestCase {
    func testCalendarsWithTimedEventsHidesCalendarsWithoutFetchedEvents() {
        let calendars = [
            CalendarInfo(id: "apple-work", title: "Work", source: .apple, colorHex: nil),
            CalendarInfo(id: "apple-holidays", title: "India Holidays", source: .apple, colorHex: nil),
            CalendarInfo(id: "ics-team", title: "Team", source: .ics, colorHex: nil)
        ]

        let now = Date()
        let events = [
            CalendarEvent(
                id: "work-1",
                title: "Design Review",
                startDate: now,
                endDate: now.addingTimeInterval(1800),
                source: .apple,
                calendarName: "Work"
            ),
            CalendarEvent(
                id: "team-1",
                title: "Planning",
                startDate: now,
                endDate: now.addingTimeInterval(1800),
                source: .ics,
                calendarName: "Team"
            )
        ]

        let filtered = EventStore.calendarsWithTimedEvents(calendars, events: events)

        XCTAssertEqual(filtered.map(\.id), ["apple-work", "ics-team"])
    }
}
