//
//  EventManager.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import Foundation

class EventManager {
    private let defaults = UserDefaults.standard
    private let eventsKey = "savedEvents"

    func saveEvents(_ events: [Event]) {
        if let encoded = try? JSONEncoder().encode(events) {
            defaults.set(encoded, forKey: eventsKey)
        }
    }

    func loadEvents() -> [Event] {
        if let savedEvents = defaults.object(forKey: eventsKey) as? Data {
            if let loadedEvents = try? JSONDecoder().decode([Event].self, from: savedEvents) {
                return loadedEvents.sorted(by: { $0.date < $1.date })
            }
        }
        return []
    }
}
