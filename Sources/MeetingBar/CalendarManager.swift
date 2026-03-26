import EventKit
import AppKit
import Combine

@MainActor
final class CalendarManager: ObservableObject {
    private let store = EKEventStore()

    @Published var meetings: [Meeting] = []
    @Published var availableCalendars: [EKCalendar] = []
    @Published var hasAccess = false

    private var refreshTimer: Timer?
    private let enabledCalendarsKey = "enabledCalendarIdentifiers"

    var enabledCalendarIDs: Set<String> {
        get {
            if let saved = UserDefaults.standard.array(forKey: enabledCalendarsKey) as? [String] {
                return Set(saved)
            }
            // Default: all calendars enabled
            return Set(availableCalendars.map { $0.calendarIdentifier })
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: enabledCalendarsKey)
            fetchMeetings()
        }
    }

    var nextMeeting: Meeting? {
        meetings.first { $0.isHappening || $0.timeUntilStart > 0 }
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fetchMeetings()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fetchMeetings()
            }
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, error in
                Task { @MainActor in
                    self?.handleAccessResult(granted: granted, error: error)
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, error in
                Task { @MainActor in
                    self?.handleAccessResult(granted: granted, error: error)
                }
            }
        }
    }

    private func handleAccessResult(granted: Bool, error: Error?) {
        hasAccess = granted
        if granted {
            loadCalendars()
            fetchMeetings()
            startAutoRefresh()
        }
    }

    private func loadCalendars() {
        availableCalendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func fetchMeetings() {
        let now = Date()
        let lookAhead = UserDefaults.standard.integer(forKey: "lookAheadHours")
        let hours = lookAhead > 0 ? lookAhead : 24
        let endDate = Calendar.current.date(byAdding: .hour, value: hours, to: now)!

        let predicate = store.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)

        let enabled = enabledCalendarIDs
        meetings = events
            .filter { enabled.contains($0.calendar.calendarIdentifier) }
            .filter { !$0.isAllDay }
            .map { event in
                let (link, type) = MeetingExtractor.extractLink(
                    url: event.url,
                    notes: event.notes,
                    location: event.location
                )
                return Meeting(
                    id: event.eventIdentifier,
                    title: event.title ?? "Untitled",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarName: event.calendar.title,
                    calendarColor: event.calendar.color,
                    meetingLink: link,
                    meetingType: type,
                    location: event.location,
                    isAllDay: event.isAllDay
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchMeetings()
            }
        }
    }

    func isCalendarEnabled(_ calendar: EKCalendar) -> Bool {
        enabledCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func toggleCalendar(_ calendar: EKCalendar) {
        var ids = enabledCalendarIDs
        if ids.contains(calendar.calendarIdentifier) {
            ids.remove(calendar.calendarIdentifier)
        } else {
            ids.insert(calendar.calendarIdentifier)
        }
        enabledCalendarIDs = ids
    }

    deinit {
        refreshTimer?.invalidate()
    }
}
