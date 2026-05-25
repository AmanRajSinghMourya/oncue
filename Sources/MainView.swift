//
//  MainView.swift
//  OnCue
//
//  Main window content. Two tabs: Calendar (month grid + upcoming) and Settings.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var eventStore: EventStore

    var body: some View {
        TabView {
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .padding(.top, 8)
        .task {
            await eventStore.refreshAll()
        }
    }
}
