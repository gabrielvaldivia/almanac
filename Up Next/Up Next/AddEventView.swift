//
//  Events.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

struct AddEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showAddEventSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: String
    @EnvironmentObject var appData: AppData
    @FocusState private var isTitleFocused: Bool // Add this line to manage focus state

    var body: some View {
            NavigationView {
                Form {
                    Section() {
                        TextField("Title", text: $newEventTitle)
                            .focused($isTitleFocused) // Apply focused state to the TextField
                    }
                    Section() {
                        DatePicker(showEndDate ? "Start Date" : "Date", selection: $newEventDate, displayedComponents: .date)
                            .datePickerStyle(DefaultDatePickerStyle())
                        if showEndDate {
                            DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle()) 
                            Button("Remove End Date") {
                                showEndDate = false
                                newEventEndDate = Date() 
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("Add End Date") {
                                showEndDate = true
                                newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date() // Set default end date to one day after start date
                            }
                        }
                    }
                    Section() {
                        HStack {
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(appData.categories, id: \.name) { category in
                                    Text(category.name).tag(category.name as String?)
                                }
                            }
                            .onAppear {
                                if selectedCategory == nil {
                                    selectedCategory = appData.defaultCategory
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Add Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            addNewEvent()
                            showAddEventSheet = false
                        }
                        .disabled(newEventTitle.isEmpty) // Disable the button if newEventTitle is empty
                    }
                }
            }
            .onAppear {
                isTitleFocused = true // Set focus to true when the view appears
                if selectedCategory == nil {
                    selectedCategory = appData.defaultCategory.isEmpty ? "Work" : appData.defaultCategory
                }
            }

    }

    func deleteEvent(at event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
        }
    }

    func addNewEvent() {
        let defaultEndDate = showEndDate ? newEventEndDate : nil
        let newEvent = Event(title: newEventTitle, date: newEventDate, endDate: defaultEndDate, color: selectedColor, category: selectedCategory) // Handle nil category
        if let index = events.firstIndex(where: { $0.date > newEvent.date }) {
            events.insert(newEvent, at: index)
        } else {
            events.append(newEvent)
        }
        
        saveEvents()
        newEventTitle = ""
        newEventDate = Date()
        newEventEndDate = Date()
        showEndDate = false
    }

    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.com.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            print("Saved events: \(events)")
        } else {
            print("Failed to encode events.")
        }
    }
}
