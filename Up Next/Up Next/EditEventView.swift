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

// Enum for delete options
enum DeleteOption {
    case thisEvent
    case allEvents
}

// Main view for editing an event
struct EditEventView: View {
    // Bindings to parent view's state
    @Binding var events: [Event]
    @Binding var selectedEvent: Event? {
        didSet {
            if let event = selectedEvent {
                repeatOption = event.repeatOption
                repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                repeatIndefinitely = event.repeatUntil == nil
                repeatCount = calculateRepeatCount(for: event)
                updateRepeatUntilOption(for: event)
                
                // Ensure custom repeat values are set correctly
                if event.repeatOption == .custom {
                    customRepeatCount = event.customRepeatCount ?? 1
                    repeatUnit = event.repeatUnit ?? "Days"
                    repeatUntilCount = event.repeatUntilCount ?? 1 // Ensure repeatUntilCount is set
                }
            }
        }
    }
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showEditSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor

    // State variables for repeat options
    @State private var repeatOption: RepeatOption = .never
    @State private var repeatUntil: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely
    @State private var repeatCount: Int = 1
    @State private var repeatIndefinitely: Bool = false
    @State private var showDeleteActionSheet = false
    @State private var deleteOption: DeleteOption = .thisEvent
    @State private var showCategoryManagementView = false
    @State private var showUpdateActionSheet = false
    @State private var showDeleteSeriesAlert = false
    @State private var showRepeatOptions = false // Change this line
    @State private var repeatUnit: String = "Days" // Add this line
    @State private var repeatUntilCount: Int = 1 // Add this line
    @State private var customRepeatCount: Int = 1 // Add this line
    @State private var shouldDismissEditSheet = false

    // Function to save the event
    var saveEvent: () -> Void

    // Environment object to access shared app data
    @EnvironmentObject var appData: AppData

    var body: some View {
        NavigationView {
            // Event form view
            EventForm(
                newEventTitle: $newEventTitle,
                newEventDate: $newEventDate,
                newEventEndDate: $newEventEndDate,
                showEndDate: $showEndDate,
                selectedCategory: $selectedCategory,
                selectedColor: $selectedColor,
                repeatOption: $repeatOption,
                repeatUntil: $repeatUntil,
                repeatUntilOption: $repeatUntilOption,
                repeatUntilCount: $repeatUntilCount, // Pass the binding
                showCategoryManagementView: $showCategoryManagementView,
                showDeleteActionSheet: $showDeleteActionSheet,
                selectedEvent: $selectedEvent,
                deleteEvent: deleteEvent,
                deleteSeries: { showDeleteSeriesAlert = true },
                showDeleteButtons: true, // Ensure delete buttons are shown in EditEventView
                showRepeatOptions: $showRepeatOptions, // Pass the binding
                repeatUnit: $repeatUnit, // Add this line
                customRepeatCount: $customRepeatCount // Add this line
            )
            .environmentObject(appData)
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar with cancel and save buttons
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showEditSheet = false
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if selectedEvent?.repeatOption == .never {
                            applyChanges(to: .thisEvent)
                            showEditSheet = false
                        } else {
                            showUpdateActionSheet = true
                        }
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedColor.color)
                                    .frame(width: 60, height: 32)
                                Text("Save")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(CustomColorPickerSheet(selectedColor: $selectedColor, showColorPickerSheet: .constant(false)).contrastColor)
                            }
                        }
                        .opacity(newEventTitle.isEmpty ? 0.3 : 1.0)
                    }
                    .disabled(newEventTitle.isEmpty)
                }
            }
            .alert(isPresented: $showDeleteActionSheet) {
                Alert(
                    title: Text("Delete Event"),
                    message: Text("Are you sure you want to delete this event?"),
                    primaryButton: .destructive(Text("Delete this event")) {
                        deleteOption = .thisEvent
                        deleteEvent()
                    },
                    secondaryButton: .cancel()
                )
            }
            .actionSheet(isPresented: $showUpdateActionSheet) {
                if selectedEvent?.repeatOption != .never {
                    return ActionSheet(
                        title: Text("Update Event"),
                        message: Text("Do you want to apply the changes to this event only or all events in the series?"),
                        buttons: [
                            .default(Text("This Event Only")) {
                                applyChanges(to: .thisEvent)
                                shouldDismissEditSheet = true
                            },
                            .default(Text("All Events in Series")) {
                                applyChanges(to: .allEvents)
                                shouldDismissEditSheet = true
                            },
                            .cancel()
                        ]
                    )
                } else {
                    applyChanges(to: .thisEvent)
                    shouldDismissEditSheet = true
                    return ActionSheet(title: Text(""), message: Text(""), buttons: [])
                }
            }
        }
        .onAppear {
            // Set initial values when the view appears
            if let event = selectedEvent {
                repeatOption = event.repeatOption
                repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                repeatIndefinitely = event.repeatUntil == nil
                repeatCount = calculateRepeatCount(for: event)
                updateRepeatUntilOption(for: event)
                
                // Ensure custom repeat values are set correctly
                if event.repeatOption == .custom {
                    customRepeatCount = event.customRepeatCount ?? 1
                    repeatUnit = event.repeatUnit ?? "Days"
                    repeatUntilCount = event.repeatUntilCount ?? 1 // Ensure repeatUntilCount is set
                }
                selectedColor = event.color
                
                // Update showRepeatOptions based on the event's repeat option
                showRepeatOptions = event.repeatOption != .never
            }
        }
        .alertController(isPresented: $showDeleteSeriesAlert, title: "Delete Series", message: "Are you sure you want to delete all events in this series?", confirmAction: deleteSeries)
        .onChange(of: shouldDismissEditSheet) { newValue in
            if newValue {
                showEditSheet = false
                shouldDismissEditSheet = false
            }
        }
        .onChange(of: selectedCategory) { newCategory in
            if newCategory == "Birthdays" || newCategory == "Holidays" {
                repeatOption = .yearly
                showRepeatOptions = true
            }
        }
    }

    // Function to delete an event
    func deleteEvent() {
        guard let event = selectedEvent else { return }
        
        switch deleteOption {
        case .thisEvent:
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events.remove(at: index)
            }
        case .allEvents:
            events.removeAll { $0.title == event.title && $0.category == event.category }
        }
        
        saveEvents()
        showEditSheet = false
    }

    // Function to delete a series of events
    func deleteSeries() {
        guard let event = selectedEvent else { return }
        events.removeAll { $0.seriesID == event.seriesID }
        saveEvents()
        showEditSheet = false
    }

    // Function to delete a single event
    func deleteSingleEvent() {
        if let event = selectedEvent {
            if let index = appData.events.firstIndex(where: { $0.id == event.id }) {
                appData.events.remove(at: index)
                appData.saveEvents()
                WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
            }
        }
    }

    // Function to get the color of the selected category
    func getCategoryColor() -> Color {
        return selectedColor.color
    }

    // Function to save events to UserDefaults
    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
        } else {
            print("Failed to encode events.")
        }
    }
    
    // Custom date formatter
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM, d, yyyy"
        return formatter
    }

    // Function to update the repeat until option based on the event's repeat until date
    private func updateRepeatUntilOption(for event: Event) {
        if let repeatUntil = event.repeatUntil {
            if repeatUntil == Calendar.current.date(byAdding: .day, value: repeatCount - 1, to: event.date) {
                repeatUntilOption = .after
            } else if Calendar.current.isDate(repeatUntil, inSameDayAs: event.date) {
                repeatUntilOption = .indefinitely
            } else if repeatUntil > event.date {
                repeatUntilOption = .onDate
            }
        } else {
            repeatUntilOption = .indefinitely
        }
    }
    
    // Function to calculate the repeat count for an event
    private func calculateRepeatCount(for event: Event) -> Int {
        guard let repeatUntil = event.repeatUntil else { return 1 }
        switch event.repeatOption {
        case .daily:
            return Calendar.current.dateComponents([.day], from: event.date, to: repeatUntil).day! + 1
        case .weekly:
            return Calendar.current.dateComponents([.weekOfYear], from: event.date, to: repeatUntil).weekOfYear! + 1
        case .monthly:
            return Calendar.current.dateComponents([.month], from: event.date, to: repeatUntil).month! + 1
        case .yearly:
            return Calendar.current.dateComponents([.year], from: event.date, to: repeatUntil).year! + 1
        case .never:
            return 1
        case .custom:
            switch repeatUnit {
            case "Days":
                return Calendar.current.dateComponents([.day], from: event.date, to: repeatUntil).day! / customRepeatCount + 1
            case "Weeks":
                return Calendar.current.dateComponents([.weekOfYear], from: event.date, to: repeatUntil).weekOfYear! / customRepeatCount + 1
            case "Months":
                return Calendar.current.dateComponents([.month], from: event.date, to: repeatUntil).month! / customRepeatCount + 1
            case "Years":
                return Calendar.current.dateComponents([.year], from: event.date, to: repeatUntil).year! / customRepeatCount + 1
            default:
                return 1
            }
        }
    }
    
    // Function to apply changes to an event or series of events
    func applyChanges(to option: DeleteOption) {
        guard let selectedEvent = selectedEvent else { return }

        // Calculate the new duration based on the updated end date
        let newDuration = Calendar.current.dateComponents([.day], from: newEventDate, to: newEventEndDate).day ?? 0

        switch option {
        case .thisEvent:
            if let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
                events[index].title = newEventTitle
                events[index].date = newEventDate
                events[index].endDate = showEndDate ? newEventEndDate : nil
                events[index].category = selectedCategory
                events[index].color = selectedColor
                events[index].repeatOption = repeatOption
                events[index].customRepeatCount = customRepeatCount
                events[index].repeatUnit = repeatUnit
            }
        case .allEvents:
            let repeatingEvents = events.filter { $0.seriesID == selectedEvent.seriesID }
            let repeatOption = self.repeatOption

            // Update the selected event
            guard let selectedIndex = events.firstIndex(where: { $0.id == selectedEvent.id }) else { return }
            events[selectedIndex].title = newEventTitle
            events[selectedIndex].date = newEventDate
            events[selectedIndex].endDate = showEndDate ? newEventEndDate : nil
            events[selectedIndex].category = selectedCategory
            events[selectedIndex].color = selectedColor
            events[selectedIndex].repeatOption = repeatOption
            events[selectedIndex].customRepeatCount = customRepeatCount
            events[selectedIndex].repeatUnit = repeatUnit

            // Update future events
            var eventCount = 1
            for (_, event) in repeatingEvents.enumerated() {
                if let eventIndex = events.firstIndex(where: { $0.id == event.id }), eventIndex > selectedIndex {
                    let previousEventDate = events[eventIndex - 1].date
                    let newEventDate: Date?
                    switch repeatOption {
                    case .daily:
                        newEventDate = Calendar.current.date(byAdding: .day, value: 1, to: previousEventDate)
                    case .weekly:
                        newEventDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: previousEventDate)
                    case .monthly:
                        newEventDate = Calendar.current.date(byAdding: .month, value: 1, to: previousEventDate)
                    case .yearly:
                        newEventDate = Calendar.current.date(byAdding: .year, value: 1, to: previousEventDate)
                    case .never:
                        newEventDate = nil
                    case .custom:
                        switch repeatUnit {
                        case "Days":
                            newEventDate = Calendar.current.date(byAdding: .day, value: customRepeatCount, to: previousEventDate)
                        case "Weeks":
                            newEventDate = Calendar.current.date(byAdding: .weekOfYear, value: customRepeatCount, to: previousEventDate)
                        case "Months":
                            newEventDate = Calendar.current.date(byAdding: .month, value: customRepeatCount, to: previousEventDate)
                        case "Years":
                            newEventDate = Calendar.current.date(byAdding: .year, value: customRepeatCount, to: previousEventDate)
                        default:
                            newEventDate = nil
                        }
                    }
                    if let newEventDate = newEventDate, eventCount < 100 {
                        events[eventIndex].title = newEventTitle
                        events[eventIndex].date = newEventDate
                        events[eventIndex].endDate = showEndDate ? Calendar.current.date(byAdding: .day, value: newDuration, to: newEventDate) : nil
                        events[eventIndex].category = selectedCategory
                        events[eventIndex].color = selectedColor
                        events[eventIndex].repeatOption = repeatOption
                        events[eventIndex].customRepeatCount = customRepeatCount
                        events[eventIndex].repeatUnit = repeatUnit
                        eventCount += 1
                    } else {
                        events.remove(at: eventIndex)
                    }
                }
            }

            // Update past events
            eventCount = 1
            for (_, event) in repeatingEvents.enumerated().reversed() {
                if let eventIndex = events.firstIndex(where: { $0.id == event.id }), eventIndex < selectedIndex {
                    let nextEventDate = events[eventIndex + 1].date
                    let newEventDate: Date?
                    switch repeatOption {
                    case .daily:
                        newEventDate = Calendar.current.date(byAdding: .day, value: -1, to: nextEventDate)
                    case .weekly:
                        newEventDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: nextEventDate)
                    case .monthly:
                        newEventDate = Calendar.current.date(byAdding: .month, value: -1, to: nextEventDate)
                    case .yearly:
                        newEventDate = Calendar.current.date(byAdding: .year, value: -1, to: nextEventDate)
                    case .never:
                        newEventDate = nil
                    case .custom:
                        switch repeatUnit {
                        case "Days":
                            newEventDate = Calendar.current.date(byAdding: .day, value: -customRepeatCount, to: nextEventDate)
                        case "Weeks":
                            newEventDate = Calendar.current.date(byAdding: .weekOfYear, value: -customRepeatCount, to: nextEventDate)
                        case "Months":
                            newEventDate = Calendar.current.date(byAdding: .month, value: -customRepeatCount, to: nextEventDate)
                        case "Years":
                            newEventDate = Calendar.current.date(byAdding: .year, value: -customRepeatCount, to: nextEventDate)
                        default:
                            newEventDate = nil
                        }
                    }
                    if let newEventDate = newEventDate, eventCount < 100 {
                        events[eventIndex].title = newEventTitle
                        events[eventIndex].date = newEventDate
                        events[eventIndex].endDate = showEndDate ? Calendar.current.date(byAdding: .day, value: newDuration, to: newEventDate) : nil
                        events[eventIndex].category = selectedCategory
                        events[eventIndex].color = selectedColor
                        events[eventIndex].repeatOption = repeatOption
                        events[eventIndex].customRepeatCount = customRepeatCount
                        events[eventIndex].repeatUnit = repeatUnit
                        eventCount += 1
                    } else {
                        events.remove(at: eventIndex)
                    }
                }
            }
        }
        
        // Check if the event will be included in the daily notification for the date of the event
        let calendar = Calendar.current
        let eventDayStart = calendar.startOfDay(for: newEventDate)
        let eventDayEnd = calendar.date(byAdding: .day, value: 1, to: eventDayStart)!
        
        let eventsOnEventDay = events.filter { event in
            let eventStart = calendar.startOfDay(for: event.date)
            return eventStart >= eventDayStart && eventStart < eventDayEnd
        }
        
        if eventsOnEventDay.contains(where: { $0.id == selectedEvent.id }) {
            print("The event '\(newEventTitle)' will be included in the daily notification for \(newEventDate).")
        } else {
            print("The event '\(newEventTitle)' will NOT be included in the daily notification for \(newEventDate).")
        }

        appData.objectWillChange.send() // Notify observers of changes
        saveEvents()
        showEditSheet = false
    }
}

// Custom view modifier for alert controller
struct AlertControllerModifier: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var confirmAction: () -> Void

    func body(content: Content) -> some View {
        content
            .background(
                AlertControllerRepresentable(
                    isPresented: $isPresented,
                    title: title,
                    message: message,
                    confirmAction: confirmAction
                )
            )
    }
}

// Representable for alert controller
struct AlertControllerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var confirmAction: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController() // A dummy view controller required to present the alert
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, uiViewController.presentedViewController == nil else { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            isPresented = false
        })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            confirmAction()
            isPresented = false
        })

        DispatchQueue.main.async {
            uiViewController.present(alert, animated: true, completion: nil)
        }
    }
}

// Extension to add alert controller modifier to any view
extension View {
    func alertController(isPresented: Binding<Bool>, title: String, message: String, confirmAction: @escaping () -> Void) -> some View {
        self.modifier(AlertControllerModifier(isPresented: isPresented, title: title, message: message, confirmAction: confirmAction))
    }
}