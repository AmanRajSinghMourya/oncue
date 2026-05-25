//
//  CalendarView.swift
//  OnCue
//
//  Calendar tab. Month grid on the left with event dots, upcoming list on the right.
//  Hover states, haptics on selection/month change, spring animation on month nav.
//

import SwiftUI
import AppKit

struct CalendarView: View {
    @EnvironmentObject var eventStore: EventStore
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 14) {
                CalendarHeader(month: $displayedMonth)

                if eventStore.isRefreshing {
                    ProgressView("Refreshing calendars…")
                        .controlSize(.small)
                        .font(.caption)
                }

                if let error = eventStore.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                MonthGrid(
                    displayedMonth: displayedMonth,
                    selectedDate: $selectedDate,
                    events: eventStore.events
                )
                SelectedDayEvents(date: selectedDate, events: eventStore.events(on: selectedDate))
                Spacer()
            }
            .frame(minWidth: 380)
            .padding(16)

            UpcomingList(events: eventStore.upcomingEvents(limit: 20))
                .frame(minWidth: 240)
                .padding(16)
        }
    }
}

// MARK: - Header (month label + chevrons + shortcuts)

struct CalendarHeader: View {
    @Binding var month: Date

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        HStack {
            Text(Self.formatter.string(from: month))
                .font(.title3.weight(.semibold))
            Spacer()
            Button { shift(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("[", modifiers: .command)
            .help("Previous month (⌘[)")

            Button { shift(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("]", modifiers: .command)
            .help("Next month (⌘])")

            Button("Today") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    month = Date()
                }
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            .buttonStyle(.borderless)
            .help("Jump to today")
        }
    }

    private func shift(by months: Int) {
        if let new = Calendar.current.date(byAdding: .month, value: months, to: month) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                month = new
            }
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}

// MARK: - Month grid

struct MonthGrid: View {
    let displayedMonth: Date
    @Binding var selectedDate: Date
    let events: [CalendarEvent]

    private let cal = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    private var weeks: [[Date?]] {
        guard let monthInterval = cal.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = cal.component(.weekday, from: firstDay)  // 1 = Sunday
        let daysBefore = firstWeekday - 1
        let numDays = cal.range(of: .day, in: .month, for: firstDay)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: daysBefore)
        for i in 0..<numDays {
            cells.append(cal.date(byAdding: .day, value: i, to: firstDay))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(daysOfWeek, id: \.self) { d in
                    Text(d)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<weeks.count, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let date = weeks[row][col]
                        DayCell(
                            date: date,
                            isSelected: date.map { cal.isDate($0, inSameDayAs: selectedDate) } ?? false,
                            isToday: date.map { cal.isDateInToday($0) } ?? false,
                            eventCount: date.map { d in
                                events.filter { cal.isDate($0.startDate, inSameDayAs: d) }.count
                            } ?? 0
                        ) {
                            if let d = date {
                                selectedDate = d
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Day cell

struct DayCell: View {
    let date: Date?
    let isSelected: Bool
    let isToday: Bool
    let eventCount: Int
    let action: () -> Void

    @State private var isHovering = false

    private let pink = Color(red: 1.0, green: 0.42, blue: 0.78)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if let date = date {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                        .foregroundColor(textColor)

                    if eventCount > 0 {
                        Circle()
                            .fill(isSelected ? .white : pink)
                            .frame(width: 4, height: 4)
                    } else {
                        Color.clear.frame(width: 4, height: 4)
                    }
                } else {
                    Text(" ")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundFill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(date == nil)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { isHovering = hovering }
        }
    }

    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return pink }
        return .primary
    }

    private var backgroundFill: Color {
        if isSelected { return pink }
        if isHovering && date != nil { return Color.gray.opacity(0.18) }
        return .clear
    }
}

// MARK: - Selected day events (under the grid)

struct SelectedDayEvents: View {
    let date: Date
    let events: [CalendarEvent]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.dayFormatter.string(from: date))
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            if events.isEmpty {
                Text("Nothing scheduled.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(events) { event in
                    HStack(spacing: 8) {
                        Circle().fill(event.source.color).frame(width: 6, height: 6)
                        Text(Self.timeFormatter.string(from: event.startDate))
                            .font(.callout.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(event.title)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Upcoming list (right sidebar)

struct UpcomingList: View {
    let events: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            if events.isEmpty {
                Text("No upcoming meetings")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(events) { event in
                            UpcomingRow(event: event)
                        }
                    }
                }
            }
        }
    }
}

struct UpcomingRow: View {
    let event: CalendarEvent
    @State private var isHovering = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(event.source.color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                Text("\(Self.dayFormatter.string(from: event.startDate)) · \(Self.timeFormatter.string(from: event.startDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.gray.opacity(0.14) : Color.gray.opacity(0.06))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
        }
    }
}
