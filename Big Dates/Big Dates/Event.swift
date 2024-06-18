//
//  Event.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import Foundation

class Event: ObservableObject, Identifiable, Codable, Equatable, Hashable {
    @Published var title: String
    @Published var date: Date
    var id: UUID

    enum CodingKeys: CodingKey {
        case title, date, id
    }

    init(title: String, date: Date, id: UUID = UUID()) {
        self.title = title
        self.date = date
        self.id = id
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        id = try container.decode(UUID.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(id, forKey: .id)
    }

    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}