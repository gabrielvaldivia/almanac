//
//  Event.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import Foundation

class Event: ObservableObject, Identifiable, Equatable, Hashable {
    @Published var title: String
    @Published var date: Date
    var id: UUID  // This property makes Event conform to Identifiable

    init(title: String, date: Date, id: UUID = UUID()) {
        self.title = title
        self.date = date
        self.id = id
    }

    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}