//
//  AppDelegate.swift
//  OnCue
//
//  Owns the AppSettings, EventStore, MeetingMonitor, and the per-screen overlay windows.
//  Also exposes a status-bar item that toggles a popover with MainView.
//

import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Owned state (lazy)

    lazy var settings: AppSettings = AppSettings()
    lazy var eventStore: EventStore = EventStore(settings: settings)

    private lazy var monitor: MeetingMonitor = MeetingMonitor(
        eventStore: eventStore,
        settings: settings,
        onTrigger: { [weak self] event in
            self?.showReminderAnimation(for: event)
        }
    )

    // MARK: - UI

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var overlays: [OverlayWindow] = []
    @Published private(set) var isReminderAnimationActive = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "Meeting Reminder")
                ?? NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Meeting Reminder")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Popover with MainView
        popover = NSPopover()
        popover.contentSize = NSSize(width: 720, height: 620)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MainView()
                .environmentObject(settings)
                .environmentObject(eventStore)
                .environmentObject(self)
                .frame(width: 720, height: 620)
        )

        // Initial event fetch + start the monitor (which schedules its own refresh timer)
        Task { @MainActor in
            await eventStore.refreshAll()
            monitor.start()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Reminder animations

    func showReminderAnimation(for event: CalendarEvent) {
        guard !isReminderAnimationActive else { return }
        guard let screen = NSScreen.main else { return }

        isReminderAnimationActive = true
        let overlay = OverlayWindow(screen: screen)
        overlays.append(overlay)
        let title = event.displayTitle
        NSLog("OnCue reminder: title='%@' source='%@' calendar='%@'", title, event.source.rawValue, event.calendarName)
        overlay.showReminder(
            title: title,
            minutesUntil: event.minutesUntil,
            reminderImageURL: ReminderImageStore.shared.displayImageURL(),
            playSound: settings.soundEnabled,
            onFinish: { [weak self, weak overlay] in
                overlay?.orderOut(nil)
                if let overlay {
                    self?.overlays.removeAll { $0 === overlay }
                }
                self?.isReminderAnimationActive = false
            }
        )
    }

    func previewReminder() {
        let demo = CalendarEvent(
            id: "test-\(UUID().uuidString)",
            title: "standup meeting",
            startDate: Date().addingTimeInterval(5 * 60),
            endDate: Date().addingTimeInterval(35 * 60),
            source: .apple,
            calendarName: "Test"
        )
        showReminderAnimation(for: demo)
    }
}
