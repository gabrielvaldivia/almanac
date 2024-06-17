//
//  ContentView.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import SwiftUI


struct ContentView: View {
    @State private var events = [Event]()
    @State private var showingAddEvent = false

    // Create a static date formatter
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"  // Updated date format
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(events.indices, id: \.self) { index in
                            NavigationLink(value: events[index]) {
                                EventRow(event: events[index])
                            }
                        }
                    }
                }
                .background(Color.white)

                // Floating Action Button
                VStack {
                    Spacer()
                    Button(action: {
                        self.showingAddEvent = true
                    }) {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                }
            }
            .navigationTitle("Upcoming")
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(events: $events)
            }
            .presentationDetents([.medium]) // Correct usage of presentationDetents
            .navigationDestination(for: Event.self) { event in
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    EventDetailView(event: $events[index], onDelete: {
                        events.remove(at: index)
                    })
                }
            }
        }
    }

    func removeEvents(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
    }

    private func isEventDateTodayOrLater(_ date: Date) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let eventDate = Calendar.current.startOfDay(for: date)
        return eventDate >= today
    }
}

struct EventRow: View {
    var event: Event

    var body: some View {
        HStack {
            Text(event.title)
                .foregroundColor(.black)
            Spacer()
            Text(ContentView.dateFormatter.string(from: event.date))
                .foregroundColor(.gray)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

