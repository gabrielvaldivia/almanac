//
//  ContentView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI

struct Event: Identifiable {
    let id = UUID()
    var title: String
    var date: Date
}

struct ContentView: View {
    @State private var events: [Event] = []
    @State private var newEventTitle: String = ""
    @State private var newEventDate: Date = Date()
    @State private var showAddEventSheet: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var selectedEvent: Event?
    
    @FocusState private var newEventTitleFocus: Bool

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(events) { event in
                        VStack(alignment: .leading) {
                            Text(event.title)
                            Text(event.date, style: .date)
                        }
                        .onTapGesture {
                            self.selectedEvent = event
                            self.newEventTitle = event.title
                            self.newEventDate = event.date
                            self.showEditSheet = true
                        }
                    }
                    .onDelete(perform: deleteEvent)
                }
                .navigationTitle("Events")
                .navigationBarTitleDisplayMode(.inline)

                Button(action: {
                    self.newEventTitle = ""
                    self.newEventDate = Date()
                    self.showAddEventSheet = true
                    self.newEventTitleFocus = true
                }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(40)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .sheet(isPresented: $showAddEventSheet, onDismiss: {
            newEventTitleFocus = false
        }) {
            NavigationView {
                Form {
                    TextField("Event Title", text: $newEventTitle)
                        .focused($newEventTitleFocus)
                    DatePicker("Event Date", selection: $newEventDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                }
                .navigationTitle("Add Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            addNewEvent()
                            showAddEventSheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                Form {
                    TextField("Edit Event Title", text: $newEventTitle)
                        .focused($newEventTitleFocus)
                    DatePicker("Edit Event Date", selection: $newEventDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                }
                .navigationTitle("Edit Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveChanges()
                            showEditSheet = false
                        }
                    }
                }
            }
        }
    }

    func deleteEvent(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
    }

    func addNewEvent() {
        let newEvent = Event(title: newEventTitle, date: newEventDate)
        events.append(newEvent)
        newEventTitle = ""
        newEventDate = Date()
    }

    func saveChanges() {
        if let selectedEvent = selectedEvent, let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
        }
    }
}

#Preview {
    ContentView()
}
