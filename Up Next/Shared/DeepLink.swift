import Foundation

enum DeepLink: Equatable {
    case addEvent
    case event(UUID)
    case home

    init?(url: URL) {
        guard url.scheme?.lowercased() == "upnext" else { return nil }
        switch url.host?.lowercased() {
        case "addevent": self = .addEvent
        case "event":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .event(id)
        case "widgettapped", "editwidget", "home": self = .home
        default: return nil
        }
    }

    static func eventURL(_ id: UUID) -> URL { URL(string: "upnext://event/\(id.uuidString)")! }
}
