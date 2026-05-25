//
//  OnCueApp.swift
//  OnCue
//
//  Entry point for the menu-bar-only app. AppDelegate owns the status item,
//  popover, event monitor, and overlay windows.
//

import SwiftUI

@main
struct OnCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
