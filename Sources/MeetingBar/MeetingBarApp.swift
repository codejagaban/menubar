import SwiftUI
import AppKit

@main
struct MeetingBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let calendarManager = CalendarManager()
    private var updateTimer: Timer?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = " No meetings"
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "MeetingBar")
            button.imagePosition = .imageLeading
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        calendarManager.requestAccess()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarTitle()
            }
        }

        Task { @MainActor in
            for await _ in calendarManager.$meetings.values {
                updateMenuBarTitle()
            }
        }
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            self.rebuildMenu(menu)
        }
    }

    // MARK: - Menu Building

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        calendarManager.fetchMeetings()

        guard calendarManager.hasAccess else {
            let item = NSMenuItem(title: "Calendar access required", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(NSMenuItem.separator())
            let openSettings = NSMenuItem(title: "Open System Settings", action: #selector(openPrivacySettings), keyEquivalent: "")
            openSettings.target = self
            menu.addItem(openSettings)
            addFooterItems(to: menu)
            return
        }

        let meetings = calendarManager.meetings

        if meetings.isEmpty {
            let item = NSMenuItem(title: "No upcoming meetings", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            addFooterItems(to: menu)
            return
        }

        // First meeting gets its own section with relative time header
        let firstMeeting = meetings[0]
        let remainingMeetings = Array(meetings.dropFirst())

        let firstHeader: String
        if firstMeeting.isHappening {
            firstHeader = "Now"
        } else {
            let minutes = Int(firstMeeting.timeUntilStart / 60)
            if minutes < 1 {
                firstHeader = "Starting now"
            } else if minutes < 60 {
                firstHeader = "Starts in \(minutes)m"
            } else {
                let hours = minutes / 60
                let rem = minutes % 60
                firstHeader = rem == 0 ? "Starts in \(hours)h" : "Starts in \(hours)h \(rem)m"
            }
        }
        addSectionHeader(to: menu, title: firstHeader)
        menu.addItem(makeMeetingItem(firstMeeting))

        // Group remaining meetings by day
        let calendar = Calendar.current
        var todayMeetings: [Meeting] = []
        var tomorrowMeetings: [Meeting] = []
        var laterMeetings: [Meeting] = []

        for meeting in remainingMeetings {
            if calendar.isDateInToday(meeting.startDate) {
                todayMeetings.append(meeting)
            } else if calendar.isDateInTomorrow(meeting.startDate) {
                tomorrowMeetings.append(meeting)
            } else {
                laterMeetings.append(meeting)
            }
        }

        if !todayMeetings.isEmpty {
            menu.addItem(NSMenuItem.separator())
            addSectionHeader(to: menu, title: "Today")
            for meeting in todayMeetings {
                menu.addItem(makeMeetingItem(meeting))
            }
        }

        if !tomorrowMeetings.isEmpty {
            menu.addItem(NSMenuItem.separator())
            addSectionHeader(to: menu, title: "Tomorrow")
            for meeting in tomorrowMeetings {
                menu.addItem(makeMeetingItem(meeting))
            }
        }

        if !laterMeetings.isEmpty {
            menu.addItem(NSMenuItem.separator())
            addSectionHeader(to: menu, title: "Later")
            for meeting in laterMeetings {
                menu.addItem(makeMeetingItem(meeting))
            }
        }

        addFooterItems(to: menu)
    }

    private func addSectionHeader(to menu: NSMenu, title: String) {
        let headerItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        headerItem.attributedTitle = NSAttributedString(string: title, attributes: headerAttrs)
        menu.addItem(headerItem)
    }

    private func makeMeetingItem(_ meeting: Meeting) -> NSMenuItem {
        let item = NSMenuItem(title: meeting.title, action: nil, keyEquivalent: "")

        let title = NSMutableAttributedString()

        // Title line
        let titlePara = NSMutableParagraphStyle()
        titlePara.paragraphSpacing = 2

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .paragraphStyle: titlePara
        ]
        title.append(NSAttributedString(string: meeting.title, attributes: titleAttrs))

        // Time line with top padding
        let timePara = NSMutableParagraphStyle()
        timePara.paragraphSpacingBefore = 2

        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: timePara
        ]
        title.append(NSAttributedString(string: "\n\(meeting.formattedTime)", attributes: timeAttrs))

        item.attributedTitle = title

        // If meeting has a link, make it clickable
        if meeting.meetingLink != nil {
            item.action = #selector(openMeetingLink(_:))
            item.target = self
            item.representedObject = meeting.meetingLink
        }

        return item
    }

    private func addFooterItems(to menu: NSMenu) {
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func openMeetingLink(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(calendarManager: calendarManager)

        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "MeetingBar Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Menu Bar Title

    private func updateMenuBarTitle() {
        guard let button = statusItem.button else { return }

        let showTitle = UserDefaults.standard.object(forKey: "showMeetingTitle") as? Bool ?? true

        if let next = calendarManager.nextMeeting {
            if showTitle {
                button.title = " \(next.menuBarString)"
            } else {
                button.title = " \(next.relativeTimeString)"
            }
        } else {
            button.title = " No meetings"
        }
    }
}
