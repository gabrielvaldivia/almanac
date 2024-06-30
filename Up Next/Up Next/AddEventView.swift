//
//  Events.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UserNotifications
import WidgetKit // Add this import

struct AddEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showAddEventSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor // Use CodableColor to store color
    @Binding var notificationsEnabled: Bool // New binding for notificationsEnabled
    @EnvironmentObject var appData: AppData
    @FocusState private var isTitleFocused: Bool // Add this line to manage focus state
    @State private var repeatOption: RepeatOption = .never // Changed from .none to .never
    @State private var repeatUntil: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()

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
                        Picker("Repeat", selection: $repeatOption) {
                            ForEach(RepeatOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        if repeatOption != .never {
                            DatePicker("Repeat Until", selection: $repeatUntil, displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle())
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
                    Section() {
                        Toggle("Notify me", isOn: $notificationsEnabled)
                    }
                    
                }
                .navigationTitle("Add Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            saveNewEvent()
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

    func saveNewEvent() {
        let newEvent = Event(
            title: newEventTitle,
            date: newEventDate,
            endDate: showEndDate ? newEventEndDate : nil,
            color: selectedColor,
            category: selectedCategory,
            notificationsEnabled: notificationsEnabled,
            repeatOption: repeatOption,
            repeatUntil: repeatOption != .never ? repeatUntil : nil
        )
        events.append(contentsOf: generateRepeatingEvents(for: newEvent))
        saveEvents()
        if newEvent.notificationsEnabled {
            appData.scheduleNotification(for: newEvent) // Call centralized function
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
    }

    func generateRepeatingEvents(for event: Event) -> [Event] {
        var repeatingEvents = [Event]()
        var currentEvent = event
        repeatingEvents.append(currentEvent)
        while let nextDate = getNextRepeatDate(for: currentEvent), nextDate <= (event.repeatUntil ?? Date()) {
            currentEvent = Event(
                title: event.title,
                date: nextDate,
                endDate: event.endDate,
                color: event.color,
                category: event.category,
                notificationsEnabled: event.notificationsEnabled,
                repeatOption: event.repeatOption,
                repeatUntil: event.repeatUntil
            )
            repeatingEvents.append(currentEvent)
        }
        return repeatingEvents
    }

    func getNextRepeatDate(for event: Event) -> Date? {
        switch event.repeatOption {
        case .never:
            return nil
        case .daily:
            return Calendar.current.date(byAdding: .day, value: 1, to: event.date)
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: event.date)
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: 1, to: event.date)
        case .yearly:
            return Calendar.current.date(byAdding: .year, value: 1, to: event.date)
        }
    }

    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            // print("Saved events: \(events)")
        } else {
            print("Failed to encode events.")
        }
    }
}
