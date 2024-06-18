//
//  EventHistoryView.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import Foundation
import SwiftUI

struct EventHistoryView: View {
    @Binding var events: [Event]
    private let eventManager = EventManager()  // Added this line

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(events.indices.filter { !isEventDateTodayOrLater(events[$0].date) }, id: \.self) { index in
                            NavigationLink(
                                destination: EventDetailView(event: events[index], onDelete: {
                                    events.remove(at: index)
                                }, onSave: {
                                    events.sort(by: { $0.date < $1.date })
                                    eventManager.saveEvents(events)
                                }),
                                label: {
                                    EventRow(event: events[index])
                                }
                            )
                            .onTapGesture {
                                print("Event tapped: \(events[index].title)")
                            }
                        }
                    }
                }
                .background(Color.white)
            }
            .navigationTitle("Event History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

func isEventDateTodayOrLater(_ date: Date) -> Bool {
    let today = Calendar.current.startOfDay(for: Date())
    let eventDate = Calendar.current.startOfDay(for: date)
    return eventDate >= today
}
