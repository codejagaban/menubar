import Foundation

struct MeetingExtractor {
    private static let patterns: [(MeetingType, String)] = [
        (.zoom, #"https?://[\w.-]*zoom\.us/[jw]/[^\s<>"',)\]]+"#),
        (.googleMeet, #"https?://meet\.google\.com/[a-z\-]+[^\s<>"',)\]]?"#),
        (.microsoftTeams, #"https?://teams\.microsoft\.com/l/meetup-join/[^\s<>"',)\]]+"#),
    ]

    static func extractLink(url: URL?, notes: String?, location: String?) -> (URL?, MeetingType) {
        // Check the event URL first
        if let url = url {
            let urlString = url.absoluteString
            for (type, _) in patterns {
                switch type {
                case .zoom where urlString.contains("zoom.us"):
                    return (url, .zoom)
                case .googleMeet where urlString.contains("meet.google.com"):
                    return (url, .googleMeet)
                case .microsoftTeams where urlString.contains("teams.microsoft.com"):
                    return (url, .microsoftTeams)
                default:
                    continue
                }
            }
            // It's a URL but not a known meeting type
            return (url, .other)
        }

        // Search through notes and location
        let searchTexts = [notes, location].compactMap { $0 }
        for text in searchTexts {
            for (type, pattern) in patterns {
                if let range = text.range(of: pattern, options: .regularExpression) {
                    let matched = String(text[range])
                    if let url = URL(string: matched) {
                        return (url, type)
                    }
                }
            }
        }

        return (nil, .none)
    }
}
