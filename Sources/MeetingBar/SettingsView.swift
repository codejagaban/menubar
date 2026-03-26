import SwiftUI
import EventKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var selectedTab = 0
    @AppStorage("showMeetingTitle") var showMeetingTitle = true
    @AppStorage("lookAheadHours") var lookAheadHours = 24

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                showMeetingTitle: $showMeetingTitle,
                lookAheadHours: $lookAheadHours
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(0)

            CalendarsSettingsView(calendarManager: calendarManager)
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }
                .tag(1)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
        .padding(20)
        .frame(width: 420, height: 340)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @Binding var showMeetingTitle: Bool
    @Binding var lookAheadHours: Int
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                Toggle("Show meeting title in menu bar", isOn: $showMeetingTitle)
            }

            Section {
                Picker("Look ahead", selection: $lookAheadHours) {
                    Text("1 hour").tag(1)
                    Text("6 hours").tag(6)
                    Text("12 hours").tag(12)
                    Text("24 hours").tag(24)
                    Text("48 hours").tag(48)
                }
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        setLaunchAtLogin(newValue)
                    }
                ))
                    .onAppear {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently handle — user may not have permission
        }
    }
}

// MARK: - Calendars

struct CalendarsSettingsView: View {
    @ObservedObject var calendarManager: CalendarManager

    private var calendarsBySource: [(String, [EKCalendar])] {
        let grouped = Dictionary(grouping: calendarManager.availableCalendars) { cal in
            cal.source?.title ?? "Other"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !calendarManager.hasAccess {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Calendar access is required")
                        .font(.body)
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if calendarManager.availableCalendars.isEmpty {
                VStack {
                    Spacer()
                    Text("No calendars found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(calendarsBySource, id: \.0) { source, calendars in
                        Section(header: Text(source)) {
                            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(nsColor: calendar.color))
                                        .frame(width: 10, height: 10)

                                    Text(calendar.title)
                                        .lineLimit(1)

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { calendarManager.isCalendarEnabled(calendar) },
                                        set: { _ in calendarManager.toggleCalendar(calendar) }
                                    ))
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("MeetingBar")
                .font(.title2)
                .fontWeight(.medium)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Made by codejagaban")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Displays upcoming meetings from your calendars in the menu bar with quick join links for Zoom, Google Meet, and Teams.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
