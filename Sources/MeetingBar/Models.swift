import AppKit
import EventKit

enum MeetingType: String {
    case zoom = "Zoom"
    case googleMeet = "Meet"
    case microsoftTeams = "Teams"
    case other = "Link"
    case none = ""
}

enum MeetingSection: String {
    case happeningNow = "Now"
    case startingSoon = "Starting soon"
    case today = "Today"
    case tomorrow = "Tomorrow"
    case later = "Later"
}

struct Meeting: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarName: String
    let calendarColor: NSColor
    let meetingLink: URL?
    let meetingType: MeetingType
    let location: String?
    let isAllDay: Bool

    var isHappening: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var timeUntilStart: TimeInterval {
        startDate.timeIntervalSinceNow
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var section: MeetingSection {
        if isHappening { return .happeningNow }
        let minutes = Int(timeUntilStart / 60)
        if minutes < 30 { return .startingSoon }

        let calendar = Calendar.current
        if calendar.isDateInToday(startDate) { return .today }
        if calendar.isDateInTomorrow(startDate) { return .tomorrow }
        return .later
    }

    var relativeTimeString: String {
        if isHappening {
            let remaining = Int(endDate.timeIntervalSinceNow / 60)
            return "now (\(remaining)m left)"
        }

        let minutes = Int(timeUntilStart / 60)
        if minutes < 1 { return "starting now" }
        if minutes < 60 { return "in \(minutes)m" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "in \(hours)h" }
        return "in \(hours)h \(remainingMinutes)m"
    }

    var sectionHeaderString: String {
        switch section {
        case .happeningNow:
            return "Now"
        case .startingSoon:
            let minutes = Int(timeUntilStart / 60)
            if minutes < 1 { return "Starting now" }
            if minutes < 60 { return "Starts in \(minutes)m" }
            let hours = minutes / 60
            let rem = minutes % 60
            if rem == 0 { return "Starts in \(hours)h" }
            return "Starts in \(hours)h \(rem)m"
        case .today:
            return "Today"
        case .tomorrow:
            return "Tomorrow"
        case .later:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: startDate)
        }
    }

    var menuBarString: String {
        let name = title.count > 20 ? String(title.prefix(18)) + " .." : title
        return "\(name) \u{2022} \(relativeTimeString)"
    }
}
