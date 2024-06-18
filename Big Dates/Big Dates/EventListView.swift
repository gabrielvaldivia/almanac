//
//  EventListView.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import SwiftUI

struct EventListView: View {
    var events: [Event]
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(events.indices.filter { isEventDateTodayOrLater(events[$0].date) }, id: \.self) { index in
                    NavigationLink(value: events[index]) {
                        EventRow(event: events[index])
                    }
                }
            }
        }
    }
}
