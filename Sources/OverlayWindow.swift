//
//  OverlayWindow.swift
//  OnCue
//
//  Transparent, click-through, screen-spanning window that hosts the reminder
//  animation. Sits above fullscreen apps via .screenSaver level + the right
//  collection behavior flags.
//

import AppKit
import SwiftUI

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true        // click-through
        level = .screenSaver              // above fullscreen apps + system UI
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        setFrame(screen.frame, display: true)
    }

    func showReminder(
        title: String,
        minutesUntil: Int,
        reminderImageURL: URL?,
        playSound: Bool,
        onFinish: @escaping () -> Void
    ) {
        let view = ReminderOverlayView(
            meetingTitle: title,
            minutesUntil: minutesUntil,
            reminderImageURL: reminderImageURL,
            onFinish: onFinish
        )
        contentView = NSHostingView(rootView: view)
        orderFrontRegardless()

        if playSound {
            NSSound(named: "Glass")?.play()
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
