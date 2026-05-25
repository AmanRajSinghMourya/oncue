//
//  ICSParser.swift
//  OnCue
//
//  RFC 5545 subset parser for .ics files + ICSCalendarProvider conforming to EventProvider.
//
//  Supported:
//  - VEVENT extraction with SUMMARY, DTSTART, DTEND, DURATION, UID, RRULE
//  - Line unfolding (CRLF + leading space/tab)
//  - DTSTART/DTEND with UTC (Z), TZID parameter, or floating local time
//  - DURATION fallback (PT#H#M#S, P#D)
//  - RRULE expansion: FREQ=DAILY|WEEKLY|MONTHLY|YEARLY, INTERVAL, COUNT, UNTIL, BYDAY
//  - 1000 iteration safety bound per recurrence
//
//  Not supported:
//  - BYDAY ordinal prefix (e.g. "1MO" treated as plain MO)
//  - EXDATE / RDATE / RECURRENCE-ID
//  - BYMONTHDAY / BYSETPOS / BYMONTH
//  - All-day events (VALUE=DATE) are skipped
//

import Foundation

// MARK: - Provider

final class ICSCalendarProvider: EventProvider {
    let source: EventSource = .ics

    func requestAccess() async throws -> Bool { true }

    func availableCalendars() async throws -> [CalendarInfo] {
        let files = ICSStore.shared.listFiles()
        return files.map { url in
            CalendarInfo(
                id: "ics:\(url.lastPathComponent)",
                title: url.deletingPathExtension().lastPathComponent,
                source: .ics,
                colorHex: "#0FAB94"
            )
        }
    }

    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent] {
        let window = DateInterval(start: from, end: max(to, from))
        let files = ICSStore.shared.listFiles()
        var all: [CalendarEvent] = []
        for url in files {
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else { continue }
            let calendarName = url.deletingPathExtension().lastPathComponent
            let events = ICSParser.parse(text: text, window: window, calendarName: calendarName)
            all.append(contentsOf: events)
        }
        return all
    }
}

// MARK: - Parser

enum ICSParser {

    static func parse(text: String, window: DateInterval, calendarName: String) -> [CalendarEvent] {
        let unfolded = unfold(text)
        let lines = unfolded.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var events: [CalendarEvent] = []
        var inEvent = false
        var props: [String: String] = [:]
        var paramMap: [String: [String: String]] = [:]

        for raw in lines {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            if line == "BEGIN:VEVENT" {
                inEvent = true
                props = [:]
                paramMap = [:]
                continue
            }
            if line == "END:VEVENT" {
                if inEvent {
                    if let expanded = makeEvents(props: props, params: paramMap, window: window, calendarName: calendarName) {
                        events.append(contentsOf: expanded)
                    }
                }
                inEvent = false
                continue
            }
            if !inEvent { continue }

            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let head = String(line[..<colonIdx])
            let value = String(line[line.index(after: colonIdx)...])

            // Split head into name + params
            let parts = head.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
            guard let name = parts.first?.uppercased() else { continue }
            var params: [String: String] = [:]
            for p in parts.dropFirst() {
                if let eq = p.firstIndex(of: "=") {
                    let k = String(p[..<eq]).uppercased()
                    let v = String(p[p.index(after: eq)...])
                    params[k] = v
                }
            }
            props[name] = value
            paramMap[name] = params
        }

        return events
    }

    // MARK: - Line unfolding

    private static func unfold(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var result = ""
        var iterator = normalized.makeIterator()
        var pendingNewline = false
        while let ch = iterator.next() {
            if pendingNewline {
                if ch == " " || ch == "\t" {
                    pendingNewline = false
                    continue
                } else {
                    result.append("\n")
                    pendingNewline = false
                }
            }
            if ch == "\n" {
                pendingNewline = true
            } else {
                result.append(ch)
            }
        }
        if pendingNewline { result.append("\n") }
        return result
    }

    // MARK: - Event construction + recurrence expansion

    private static func makeEvents(
        props: [String: String],
        params: [String: [String: String]],
        window: DateInterval,
        calendarName: String
    ) -> [CalendarEvent]? {
        guard let dtstartRaw = props["DTSTART"] else { return nil }
        let dtstartParams = params["DTSTART"] ?? [:]

        if dtstartParams["VALUE"]?.uppercased() == "DATE" { return nil }

        guard let start = parseDate(value: dtstartRaw, params: dtstartParams) else { return nil }

        let end: Date
        if let dtendRaw = props["DTEND"], let parsed = parseDate(value: dtendRaw, params: params["DTEND"] ?? [:]) {
            end = parsed
        } else if let duration = props["DURATION"], let secs = parseDuration(duration) {
            end = start.addingTimeInterval(secs)
        } else {
            end = start.addingTimeInterval(30 * 60)
        }

        let title = unescape(props["SUMMARY"] ?? "Untitled")
        let uid = props["UID"] ?? UUID().uuidString

        if props["RRULE"] == nil {
            guard window.intersects(DateInterval(start: start, end: max(end, start))) else { return [] }
            return [CalendarEvent(
                id: "ics-\(uid)",
                title: title,
                startDate: start,
                endDate: end,
                source: .ics,
                calendarName: calendarName
            )]
        }

        return expandRRule(
            rrule: props["RRULE"]!,
            start: start,
            duration: end.timeIntervalSince(start),
            window: window,
            title: title,
            uid: uid,
            calendarName: calendarName
        )
    }

    private static func expandRRule(
        rrule: String,
        start: Date,
        duration: TimeInterval,
        window: DateInterval,
        title: String,
        uid: String,
        calendarName: String
    ) -> [CalendarEvent] {
        var freq: String?
        var interval: Int = 1
        var count: Int?
        var until: Date?
        var byday: [String] = []

        for part in rrule.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            let k = kv[0].uppercased()
            let v = kv[1]
            switch k {
            case "FREQ": freq = v.uppercased()
            case "INTERVAL": interval = max(1, Int(v) ?? 1)
            case "COUNT": count = Int(v)
            case "UNTIL": until = parseDate(value: v, params: [:])
            case "BYDAY": byday = v.split(separator: ",").map { String($0).uppercased() }
            default: break
            }
        }

        guard let freq else { return [] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        var occurrences: [CalendarEvent] = []
        var iter = start
        var emitted = 0
        let maxIterations = 1000
        var safety = 0

        let weekdayMap: [String: Int] = [
            "SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7
        ]
        let bydayNums: [Int] = byday.compactMap { code in
            let clean = String(code.suffix(2)).uppercased()
            return weekdayMap[clean]
        }

        while safety < maxIterations {
            safety += 1
            if let until, iter > until { break }
            if let count, emitted >= count { break }
            if iter > window.end.addingTimeInterval(366 * 24 * 3600) { break }

            var emitDates: [Date] = []
            if freq == "WEEKLY", !bydayNums.isEmpty {
                guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: iter) else { break }
                for wd in bydayNums {
                    var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .hour, .minute, .second], from: iter)
                    comps.weekday = wd
                    if let d = calendar.date(from: comps), weekInterval.contains(d), d >= start {
                        emitDates.append(d)
                    }
                }
            } else {
                emitDates.append(iter)
            }

            emitDates.sort()
            for d in emitDates {
                if let until, d > until { break }
                if let count, emitted >= count { break }
                let occEnd = d.addingTimeInterval(duration)
                if window.intersects(DateInterval(start: d, end: max(occEnd, d))) {
                    occurrences.append(CalendarEvent(
                        id: "ics-\(uid)-\(Int(d.timeIntervalSince1970))",
                        title: title,
                        startDate: d,
                        endDate: occEnd,
                        source: .ics,
                        calendarName: calendarName
                    ))
                }
                emitted += 1
            }

            var comp = DateComponents()
            switch freq {
            case "DAILY": comp.day = interval
            case "WEEKLY": comp.weekOfYear = interval
            case "MONTHLY": comp.month = interval
            case "YEARLY": comp.year = interval
            default: return occurrences
            }
            guard let next = calendar.date(byAdding: comp, to: iter) else { break }
            if next == iter { break }
            iter = next
        }

        return occurrences
    }

    // MARK: - Date parsing

    private static func parseDate(value: String, params: [String: String]) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.count == 8 {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd"
            f.timeZone = TimeZone(identifier: "UTC")
            return f.date(from: trimmed)
        }

        let isUTC = trimmed.hasSuffix("Z")
        let core = isUTC ? String(trimmed.dropLast()) : trimmed

        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss"

        if isUTC {
            f.timeZone = TimeZone(identifier: "UTC")
        } else if let tzid = params["TZID"], let tz = TimeZone(identifier: tzid) {
            f.timeZone = tz
        } else {
            f.timeZone = .current
        }

        return f.date(from: core)
    }

    private static func parseDuration(_ s: String) -> TimeInterval? {
        guard s.hasPrefix("P") else { return nil }
        var rest = String(s.dropFirst())
        var total: TimeInterval = 0
        var inTime = false

        while !rest.isEmpty {
            if rest.hasPrefix("T") {
                inTime = true
                rest.removeFirst()
                continue
            }
            var numStr = ""
            while let c = rest.first, c.isNumber {
                numStr.append(c)
                rest.removeFirst()
            }
            guard let n = Double(numStr), let unit = rest.first else { return nil }
            rest.removeFirst()
            switch unit {
            case "D": total += n * 86400
            case "H" where inTime: total += n * 3600
            case "M" where inTime: total += n * 60
            case "S" where inTime: total += n
            case "W": total += n * 7 * 86400
            default: return nil
            }
        }
        return total
    }

    private static func unescape(_ s: String) -> String {
        return s
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
