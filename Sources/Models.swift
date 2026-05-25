//
//  Models.swift
//  OnCue
//
//  Unified event model, source enum, and persisted app settings.
//

import Foundation
import SwiftUI

// MARK: - Calendar event (source-agnostic)

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let source: EventSource
    let calendarName: String

    var minutesUntil: Int {
        max(0, Int(startDate.timeIntervalSinceNow / 60))
    }
}

enum EventSource: String, Codable, CaseIterable {
    case apple
    case ics

    var displayName: String {
        switch self {
        case .apple: return "Apple Calendar"
        case .ics:   return "Imported (.ics)"
        }
    }

    /// Per-source dot color used in the calendar grid + upcoming list.
    var color: Color {
        switch self {
        case .apple: return Color(red: 1.0, green: 0.42, blue: 0.78)  // pink
        case .ics:   return Color(red: 0.06, green: 0.67, blue: 0.58) // teal
        }
    }
}

// MARK: - Calendar metadata (one entry per imported calendar)

struct CalendarInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let source: EventSource
    let colorHex: String?
}

// MARK: - App settings (UserDefaults-backed)

final class AppSettings: ObservableObject {
    static let leadTimeRange = 1...120
    static let defaultLeadTimeMinutes = 5

    private let defaults: UserDefaults

    @Published var leadTimeMinutes: Int {
        didSet {
            let clamped = Self.clampedLeadTime(leadTimeMinutes)
            if leadTimeMinutes != clamped {
                leadTimeMinutes = clamped
            }
            defaults.set(clamped, forKey: Keys.leadTime)
        }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.sound) }
    }
    @Published var appleEnabled: Bool {
        didSet { defaults.set(appleEnabled, forKey: Keys.apple) }
    }
    @Published var icsEnabled: Bool {
        didSet { defaults.set(icsEnabled, forKey: Keys.ics) }
    }
    /// Calendar IDs the user has opted into. Only meaningful when `hasCustomizedCalendars` is true.
    /// ICS calendar IDs are based on filenames, while events carry the display
    /// name; `allows(_:calendars:)` intentionally bridges them by title+source.
    @Published var enabledCalendarIDs: Set<String> {
        didSet {
            defaults.set(Array(enabledCalendarIDs), forKey: Keys.enabledCalIDs)
        }
    }
    /// False until the user toggles any per-calendar switch.
    @Published var hasCustomizedCalendars: Bool {
        didSet { defaults.set(hasCustomizedCalendars, forKey: Keys.hasCustomized) }
    }

    private enum Keys {
        static let leadTime = "leadTimeMinutes"
        static let sound = "soundEnabled"
        static let apple = "appleEnabled"
        static let ics = "icsEnabled"
        static let enabledCalIDs = "enabledCalendarIDs"
        static let hasCustomized = "hasCustomizedCalendars"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        let savedLeadTime = (userDefaults.object(forKey: Keys.leadTime) as? Int) ?? Self.defaultLeadTimeMinutes
        self.leadTimeMinutes = Self.clampedLeadTime(savedLeadTime)
        self.soundEnabled = (userDefaults.object(forKey: Keys.sound) as? Bool) ?? true
        self.appleEnabled = (userDefaults.object(forKey: Keys.apple) as? Bool) ?? true
        self.icsEnabled = (userDefaults.object(forKey: Keys.ics) as? Bool) ?? true
        self.enabledCalendarIDs = Set(userDefaults.array(forKey: Keys.enabledCalIDs) as? [String] ?? [])
        self.hasCustomizedCalendars = (userDefaults.object(forKey: Keys.hasCustomized) as? Bool) ?? false
    }

    static func clampedLeadTime(_ minutes: Int) -> Int {
        min(max(minutes, leadTimeRange.lowerBound), leadTimeRange.upperBound)
    }

    /// An event is allowed if its source is enabled AND (either the user hasn't
    /// customized per-calendar OR the calendar is explicitly enabled).
    func allows(_ event: CalendarEvent, calendars: [CalendarInfo]) -> Bool {
        switch event.source {
        case .apple where !appleEnabled: return false
        case .ics where !icsEnabled: return false
        default: break
        }
        if !hasCustomizedCalendars { return true }
        if let cal = calendars.first(where: { $0.title == event.calendarName && $0.source == event.source }) {
            return enabledCalendarIDs.contains(cal.id)
        }
        return true
    }
}
