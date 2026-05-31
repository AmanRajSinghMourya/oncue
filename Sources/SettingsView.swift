//
//  SettingsView.swift
//  OnCue
//
//  Settings UI: reminder timing, sound, reminder image, sources (Apple + ICS),
//  per-calendar toggles, ICS file management.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var appDelegate: AppDelegate

    @State private var icsFiles: [URL] = []
    /// Bumped whenever the reminder image changes.
    @State private var imageRefreshToken: Int = 0
    @State private var customLeadTimeText = ""
    @State private var isShowingExportInstructions = false
    @FocusState private var isLeadTimeFieldFocused: Bool

    private let leadTimePresets = [5, 10, 15, 30, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                generalSection
                Divider()
                imageSection
                Divider()
                sourcesSection
                Divider()
                icsSection
                Divider()
                testSection
                Divider()
                updatesSection
            }
            .padding(20)
        }
        .task {
            refreshICSFiles()
            syncLeadTimeText()
        }
        .sheet(isPresented: $isShowingExportInstructions) {
            ExportInstructionsSheet()
        }
    }

    // MARK: - Reminder

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder timing").font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Reminder appears")
                    Spacer()
                    Text("\(formattedLeadTime(settings.leadTimeMinutes)) before events")
                        .font(.headline)
                        .monospacedDigit()
                }

                HStack(spacing: 14) {
                    Picker("Quick picks", selection: leadTimeMinutesBinding) {
                        ForEach(leadTimePresets, id: \.self) { minutes in
                            Text(shortLeadTime(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        Text("Custom")
                            .foregroundStyle(.secondary)
                        TextField("1-120", text: $customLeadTimeText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 64)
                            .multilineTextAlignment(.trailing)
                            .focused($isLeadTimeFieldFocused)
                            .onSubmit { normalizeLeadTimeText() }
                            .onChange(of: customLeadTimeText) { _, newValue in
                                applyCustomLeadTime(newValue)
                            }
                            .onChange(of: isLeadTimeFieldFocused) { _, isFocused in
                                if !isFocused { normalizeLeadTimeText() }
                            }
                            .help("Enter a value from 1 to 120 minutes.")
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Toggle("Play sound with reminder", isOn: $settings.soundEnabled)
            Text("The reminder crosses your screen \(formattedLeadTime(settings.leadTimeMinutes)) before a timed calendar event.")
                .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onChange(of: settings.leadTimeMinutes) { _, _ in
            if !isLeadTimeFieldFocused {
                syncLeadTimeText()
            }
        }
    }

    private var leadTimeMinutesBinding: Binding<Int> {
        Binding(
            get: { settings.leadTimeMinutes },
            set: { settings.leadTimeMinutes = AppSettings.clampedLeadTime($0) }
        )
    }

    private func shortLeadTime(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    private func formattedLeadTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        let hourText = hours == 1 ? "1 hour" : "\(hours) hours"

        guard remainder > 0 else { return hourText }
        let minuteText = remainder == 1 ? "1 minute" : "\(remainder) minutes"
        return "\(hourText) \(minuteText)"
    }

    private func applyCustomLeadTime(_ newValue: String) {
        let digitsOnly = newValue.filter(\.isNumber)
        if digitsOnly != newValue {
            customLeadTimeText = digitsOnly
            return
        }

        guard let value = Int(digitsOnly) else { return }
        let clamped = AppSettings.clampedLeadTime(value)
        settings.leadTimeMinutes = clamped

        if value != clamped {
            customLeadTimeText = "\(clamped)"
        }
    }

    private func normalizeLeadTimeText() {
        if customLeadTimeText.isEmpty {
            syncLeadTimeText()
            return
        }

        let value = Int(customLeadTimeText) ?? settings.leadTimeMinutes
        settings.leadTimeMinutes = AppSettings.clampedLeadTime(value)
        syncLeadTimeText()
    }

    private func syncLeadTimeText() {
        customLeadTimeText = "\(settings.leadTimeMinutes)"
    }

    // MARK: - Reminder image

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminder image").font(.headline)
            ReminderImagePicker(refreshToken: $imageRefreshToken)
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event sources").font(.headline)

            Toggle(isOn: $settings.appleEnabled) {
                Label("Apple Calendar", systemImage: "calendar")
            }
            .help("Read timed events from calendars connected to macOS Calendar.")
            .onChange(of: settings.appleEnabled) { _, _ in
                Task { await eventStore.refreshAll() }
            }

            Toggle(isOn: $settings.icsEnabled) {
                Label("Imported .ics calendars", systemImage: "doc.text")
            }
            .help("Read timed events from imported .ics files.")
            .onChange(of: settings.icsEnabled) { _, _ in
                Task { await eventStore.refreshAll() }
            }

            if !eventStore.calendars.isEmpty {
                Text("Calendars that can trigger reminders")
                    .font(.subheadline)
                    .padding(.top, 8)
                ForEach(eventStore.calendars, id: \.id) { cal in
                    calendarRow(cal)
                }
                if !settings.hasCustomizedCalendars {
                    Text("Timed calendars are enabled by default. Toggle any calendar to customize.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func calendarRow(_ cal: CalendarInfo) -> some View {
        HStack {
            Circle()
                .fill(cal.source.color)
                .frame(width: 10, height: 10)
            Text(cal.title)
            Text("·").foregroundStyle(.secondary)
            Text(cal.source.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: {
                    if !settings.hasCustomizedCalendars { return true }
                    return settings.enabledCalendarIDs.contains(cal.id)
                },
                set: { isOn in
                    // First toggle: switch to customized mode, seed with current set
                    if !settings.hasCustomizedCalendars {
                        settings.enabledCalendarIDs = Set(eventStore.calendars.map(\.id))
                        settings.hasCustomizedCalendars = true
                    }
                    if isOn { settings.enabledCalendarIDs.insert(cal.id) }
                    else { settings.enabledCalendarIDs.remove(cal.id) }
                    Task { await eventStore.refreshAll() }
                }
            ))
            .labelsHidden()
            .help("Events from this calendar can trigger reminders.")
        }
    }

    // MARK: - ICS section

    private var icsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import .ics calendars").font(.headline)

            ICSImporter(onImported: {
                refreshICSFiles()
                Task { await eventStore.refreshAll() }
            })

            if !icsFiles.isEmpty {
                Text("Imported files").font(.subheadline).padding(.top, 8)
                ForEach(icsFiles, id: \.self) { url in
                    ICSFileRow(url: url, onDelete: {
                        try? ICSStore.shared.delete(url)
                        refreshICSFiles()
                        Task { await eventStore.refreshAll() }
                    })
                }
            }

            Button {
                isShowingExportInstructions = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export instructions")
                        Text("Show steps for Google Calendar, Apple Calendar, Outlook, and more.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

        }
    }

    private func refreshICSFiles() {
        icsFiles = ICSStore.shared.listFiles()
    }

    // MARK: - Test

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview").font(.headline)
            Button(appDelegate.isReminderAnimationActive ? "Preview running" : "Preview reminder") {
                appDelegate.previewReminder()
            }
            .buttonStyle(.borderedProminent)
            .disabled(appDelegate.isReminderAnimationActive)
            .help(appDelegate.isReminderAnimationActive ? "Wait for the current reminder animation to finish." : "Preview the reminder animation.")
            Text("Shows the reminder animation so you can check how it looks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Updates").font(.headline)
            Button {
                openLatestRelease()
            } label: {
                Label("Check for updates", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .help("Open the latest OnCue release on GitHub.")

            Text("Opens GitHub Releases. OnCue does not check for updates in the background.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func openLatestRelease() {
        guard let url = URL(string: "https://github.com/AmanRajSinghMourya/oncue/releases/latest") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Export instructions

struct ExportInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Export .ics calendars")
                    .font(.title3.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 14) {
                instructionRow(
                    title: "Google Calendar",
                    systemImage: "globe",
                    text: "Open Google Calendar settings, choose a calendar under Settings for my calendars, then export it as an .ics file."
                )
                instructionRow(
                    title: "Apple Calendar",
                    systemImage: "applelogo",
                    text: "Use File > Export > Export, or keep Apple Calendar enabled above if your events are already in the macOS Calendar app."
                )
                instructionRow(
                    title: "Outlook",
                    systemImage: "envelope",
                    text: "In Outlook for Mac, use File > Save Calendar. On outlook.com, publish the calendar from Settings > Calendar > Shared calendars, then download the ICS file."
                )
                instructionRow(
                    title: "Fastmail / Fantastical",
                    systemImage: "calendar.badge.plus",
                    text: "Look for an iCal, ICS, export, or webcal link, download the file, then drop it into this app."
                )
            }

            Text("Re-export the same file later and drop it again to refresh imported events.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 520)
    }

    private func instructionRow(title: String, systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - ICS importer (drag-drop + file picker)

struct ICSImporter: View {
    var onImported: () -> Void
    @State private var isTargeted = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                    )
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Drop a .ics file here")
                        .font(.subheadline)
                    Button("Choose file…") { pickFile() }
                        .buttonStyle(.bordered)
                }
                .padding(.vertical, 16)
            }
            .frame(height: 110)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            if url.pathExtension.lowercased() != "ics" {
                DispatchQueue.main.async { errorText = "Not an .ics file." }
                return
            }
            do {
                _ = try ICSStore.shared.importFile(from: url)
                DispatchQueue.main.async {
                    errorText = nil
                    onImported()
                }
            } catch {
                DispatchQueue.main.async {
                    errorText = error.localizedDescription
                }
            }
        }
        return true
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "ics") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                _ = try ICSStore.shared.importFile(from: url)
                errorText = nil
                onImported()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Single .ics row

struct ICSFileRow: View {
    let url: URL
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
            VStack(alignment: .leading) {
                Text(url.deletingPathExtension().lastPathComponent)
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
    }
}

// MARK: - Reminder image picker

struct ReminderImagePicker: View {
    @Binding var refreshToken: Int
    @State private var isTargeted = false

    private var currentImage: NSImage? { ReminderImageStore.shared.displayImage() }
    private var hasCustom: Bool { ReminderImageStore.shared.currentImageURL() != nil }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
                if let image = currentImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    DefaultFlybyAssetView(animated: false)
                        .padding(.horizontal, 4)
                }
            }
            .frame(width: 112, height: 72)
            .id(refreshToken) // force redraw on change
            .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)

            VStack(alignment: .leading, spacing: 6) {
                Button("Choose image…") { pickImage() }
                    .buttonStyle(.bordered)
                if hasCustom {
                    Button("Reset to default") {
                        ReminderImageStore.shared.clear()
                        refreshToken += 1
                    }
                    .buttonStyle(.borderless)
                }
                Text("PNG with transparency works best. Or drop an image onto the preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, let image = NSImage(contentsOf: url) else { return }
            DispatchQueue.main.async {
                _ = try? ReminderImageStore.shared.save(image)
                refreshToken += 1
            }
        }
        return true
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            _ = try? ReminderImageStore.shared.save(image)
            refreshToken += 1
        }
    }
}
