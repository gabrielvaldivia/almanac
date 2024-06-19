//
//  PastEventsView.swift
//  Upcoming
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import Foundation
import SwiftUI

struct PastEventsView: View {
    @Binding var events: [Event]

    var body: some View {
        List {
            ForEach(events.filter { $0.date < Date() }, id: \.id) { event in
                Text(event.title)
            }
        }
        .navigationTitle("Past Events")
    }
}