//
//  EventProviders.swift
//  OnCue
//
//  Defines the EventProvider protocol and the Apple Calendar implementation.
//  The ICS implementation lives in ICSParser.swift.
//

import Foundation
import EventKit
import AppKit

protocol EventProvider {
    var source: EventSource { get }
    func requestAccess() async throws -> Bool
    func availableCalendars() async throws -> [CalendarInfo]
    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent]
}

// MARK: - Apple Calendar (EventKit)

final class AppleCalendarProvider: EventProvider {
    let source: EventSource = .apple
    private let store = EKEventStore()

    func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await store.requestAccess(to: .event)
        }
    }

    func availableCalendars() async throws -> [CalendarInfo] {
        store.calendars(for: .event).map { cal in
            CalendarInfo(
                id: cal.calendarIdentifier,
                title: cal.title,
                source: .apple,
                colorHex: hexString(from: cal.cgColor)
            )
        }
    }

    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.compactMap { ek in
            // Skip all-day events — we want timed meetings.
            guard !ek.isAllDay else { return nil }
            let baseID = ek.eventIdentifier ?? ek.calendarItemIdentifier
            let occurrenceID = "\(baseID)-\(Int(ek.startDate.timeIntervalSince1970))"
            return CalendarEvent(
                id: occurrenceID,
                title: ek.title ?? "(No title)",
                startDate: ek.startDate,
                endDate: ek.endDate,
                source: .apple,
                calendarName: ek.calendar.title
            )
        }
    }

    private func hexString(from cgColor: CGColor?) -> String? {
        guard let cgColor, let comps = cgColor.components, comps.count >= 3 else { return nil }
        let r = Int((comps[0]).clamped(0, 1) * 255)
        let g = Int((comps[1]).clamped(0, 1) * 255)
        let b = Int((comps[2]).clamped(0, 1) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, lo), hi)
    }
}
