//
//  Event.swift
//  Upcoming
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import Foundation

struct Event: Identifiable, Comparable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    
    static func < (lhs: Event, rhs: Event) -> Bool {
        lhs.date < rhs.date
    }
}