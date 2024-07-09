//
//  EventLoader.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/1/24.
//

import Foundation

struct EventLoader {
    static func loadEvents(for category: String? = nil) -> [Event] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events"),
           let decoded = try? decoder.decode([Event].self, from: data) {
            let today = Calendar.current.startOfDay(for: Date())
            let upcomingEvents = decoded.filter { event in
                let eventDate = event.endDate ?? event.date
                return eventDate >= today
            }
            if let category = category, category != "All Categories" {
                return upcomingEvents.filter { event in
                    safeStringCompare(event.category, category)
                }
            } else {
                return upcomingEvents
            }
        } else {
            return []
        }
    }

    private static func safeStringCompare(_ str1: String?, _ str2: String?) -> Bool {
        return str1?.caseInsensitiveCompare(str2 ?? "") == .orderedSame
    }
}