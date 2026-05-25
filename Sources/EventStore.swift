//
//  EventStore.swift
//  OnCue
//
//  Aggregates events from all enabled providers (Apple Calendar + ICS imports).
//

import Foundation
import Combine

private enum EventStoreError: LocalizedError {
    case calendarAccessDenied

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            return "Calendar access was denied. Enable OnCue in System Settings → Privacy & Security → Calendars."
        }
    }
}

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var calendars: [CalendarInfo] = []
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing: Bool = false

    private let appleProvider = AppleCalendarProvider()
    private let icsProvider = ICSCalendarProvider()

    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        var allCalendars: [CalendarInfo] = []
        var allEvents: [CalendarEvent] = []
        var firstError: String?

        let now = Date()
        let horizon = now.addingTimeInterval(30 * 24 * 3600)
        let from = now.addingTimeInterval(-3600)

        if settings.appleEnabled {
            do {
                guard try await appleProvider.requestAccess() else {
                    throw EventStoreError.calendarAccessDenied
                }
                let cals = try await appleProvider.availableCalendars()
                let evs = try await appleProvider.fetchEvents(from: from, to: horizon)
                allCalendars.append(contentsOf: cals)
                allEvents.append(contentsOf: evs)
            } catch {
                firstError = firstError ?? "Apple Calendar: \(error.localizedDescription)"
            }
        }

        if settings.icsEnabled {
            do {
                let cals = try await icsProvider.availableCalendars()
                let evs = try await icsProvider.fetchEvents(from: from, to: horizon)
                allCalendars.append(contentsOf: cals)
                allEvents.append(contentsOf: evs)
            } catch {
                firstError = firstError ?? "ICS: \(error.localizedDescription)"
            }
        }

        let relevantCalendars = Self.calendarsWithTimedEvents(allCalendars, events: allEvents)

        // Filter through settings (source + per-calendar opt-in)
        let filtered = allEvents.filter { settings.allows($0, calendars: relevantCalendars) }

        self.calendars = relevantCalendars
        self.events = filtered.sorted { $0.startDate < $1.startDate }
        self.lastError = firstError
    }

    static func calendarsWithTimedEvents(
        _ calendars: [CalendarInfo],
        events: [CalendarEvent]
    ) -> [CalendarInfo] {
        let activeCalendarKeys = Set(events.map { CalendarKey(source: $0.source, title: $0.calendarName) })
        return calendars.filter { activeCalendarKeys.contains(CalendarKey(source: $0.source, title: $0.title)) }
    }

    // MARK: - Convenience queries used by CalendarView

    func events(on date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.startDate, inSameDayAs: date) }
    }

    func upcomingEvents(limit: Int) -> [CalendarEvent] {
        let now = Date()
        return events
            .filter { $0.startDate >= now }
            .prefix(limit)
            .map { $0 }
    }
}

private struct CalendarKey: Hashable {
    let source: EventSource
    let title: String
}
