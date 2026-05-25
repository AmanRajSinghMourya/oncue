//
//  MeetingMonitor.swift
//  OnCue
//
//  Polls the EventStore on a timer and fires the trigger callback when an
//  enabled event is within the configured lead time. Dedupes via event ID.
//

import Foundation

@MainActor
final class MeetingMonitor {
    private let eventStore: EventStore
    private let settings: AppSettings
    private let onTrigger: (CalendarEvent) -> Void

    private var checkTimer: Timer?
    private var refreshTimer: Timer?
    private var triggeredEventIDs = Set<String>()

    init(eventStore: EventStore,
         settings: AppSettings,
         onTrigger: @escaping (CalendarEvent) -> Void) {
        self.eventStore = eventStore
        self.settings = settings
        self.onTrigger = onTrigger
    }

    func start() {
        checkUpcoming()

        // Check every 30s for events crossing the lead-time threshold.
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkUpcoming() }
        }
        // Refresh the event store every 5 min.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.eventStore.refreshAll() }
        }
    }

    func stop() {
        checkTimer?.invalidate()
        refreshTimer?.invalidate()
        checkTimer = nil
        refreshTimer = nil
    }

    private func checkUpcoming() {
        let leadSeconds = TimeInterval(settings.leadTimeMinutes * 60)
        let now = Date()

        for event in eventStore.events {
            guard settings.allows(event, calendars: eventStore.calendars) else { continue }
            guard !triggeredEventIDs.contains(event.id) else { continue }

            let triggerTime = event.startDate.addingTimeInterval(-leadSeconds)
            // Fire when we cross the trigger threshold and the event hasn't started yet.
            if now >= triggerTime && now < event.startDate {
                triggeredEventIDs.insert(event.id)
                onTrigger(event)
            }
        }

        // GC: drop IDs for events that ended over an hour ago.
        triggeredEventIDs = triggeredEventIDs.filter { id in
            guard let event = eventStore.events.first(where: { $0.id == id }) else { return false }
            return event.endDate.timeIntervalSinceNow > -3600
        }
    }
}
