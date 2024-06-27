//
//  Events.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import WidgetKit
import UserNotifications

struct EditEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event? {
        didSet {
            if let event = selectedEvent {
                notificationsEnabled = event.notificationsEnabled
            }
        }
    }
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showEditSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor // Use CodableColor to store color
    @Binding var notificationsEnabled: Bool // New binding for notificationsEnabled
    var saveEvent: () -> Void
    @EnvironmentObject var appData: AppData

    var body: some View {
            NavigationView {
                Form {
                    Section() {
                        TextField("Title", text: $newEventTitle)
                    }
                    Section() {
                        DatePicker(showEndDate ? "Start Date" : "Date", selection: $newEventDate, displayedComponents: .date)
                            .datePickerStyle(DefaultDatePickerStyle()) // Set to WheelDatePickerStyle for expanded view
                        if showEndDate {
                            DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle()) // Set to WheelDatePickerStyle for expanded view
                            Button("Remove End Date") {
                                showEndDate = false
                                newEventEndDate = Date() // Reset end date to default
                            }
                            .foregroundColor(.red) // Set button text color to red
                        } else {
                            Button("Add End Date") {
                                showEndDate = true
                                newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date() // Set default end date to one day after start date
                            }
                        }
                    }
                    Section() {
                        HStack {
                            Text("Category")
                            Spacer()
                            Menu {
                                Picker("Select Category", selection: $selectedCategory) {
                                    ForEach(appData.categories, id: \.name) { category in
                                        Text(category.name).tag(category.name as String?)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCategory ?? "Select")
                                        .foregroundColor(.gray)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    Section() {
                        Toggle("Notify me", isOn: $notificationsEnabled)
                    }
                }
                .navigationTitle("Edit Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveEvent()
                        }
                        .disabled(newEventTitle.isEmpty) // Disable the button if newEventTitle is empty
                    }
                    ToolbarItem(placement: .bottomBar) { // Add this ToolbarItem for delete button
                        Button("Delete Event") {
                            if let event = selectedEvent {
                                deleteEvent(at: event)
                            }
                            showEditSheet = false // Dismiss the sheet
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                if let event = selectedEvent {
                    notificationsEnabled = event.notificationsEnabled
                }
            }
    }

    func deleteEvent(at event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
            saveEvents()  // Save after deleting
        }
    }

    func saveChanges() {
        if let selectedEvent = selectedEvent, let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
            events[index].endDate = showEndDate ? newEventEndDate : nil
            events[index].color = selectedColor
            events[index].category = selectedCategory
            events[index].notificationsEnabled = notificationsEnabled
            saveEvents()
            if events[index].notificationsEnabled {
                scheduleNotification(for: events[index]) // Schedule notification
            } else {
                removeNotification(for: events[index]) // Remove notification
            }
        }
    }

    func sortEvents() {
        events.sort { $0.date < $1.date }
    }

    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            print("Saved events: \(events)")
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
        } else {
            print("Failed to encode events.")
        }
    }

    func scheduleNotification(for event: Event) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "Event is starting soon!"
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for event: \(event.title)")
            }
        }
    }

    func removeNotification(for event: Event) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [event.id.uuidString])
        print("Notification removed for event: \(event.title).")
    }
}

// Preview Provider
struct EditEventView_Previews: PreviewProvider {
    static var previews: some View {
        EditEventView(
            events: .constant([]),
            selectedEvent: .constant(nil),
            newEventTitle: .constant(""),
            newEventDate: .constant(Date()),
            newEventEndDate: .constant(Date()),
            showEndDate: .constant(false),
            showEditSheet: .constant(false),
            selectedCategory: .constant(nil),
            selectedColor: .constant(CodableColor(color: .black)), // Use CodableColor for selectedColor
            notificationsEnabled: .constant(true), // New binding for notificationsEnabled
            saveEvent: {} // Provide a dummy implementation for the saveEvent parameter
        )
        .environmentObject(AppData())
    }
}
