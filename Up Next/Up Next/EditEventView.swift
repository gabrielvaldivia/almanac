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

// Struct for event details
public struct EventDetails {
    var title: String
    var selectedEvent: Event?
}

// Struct for date options
public struct DateOptions {
    var date: Date
    var endDate: Date
    var showEndDate: Bool
    var repeatOption: RepeatOption
    var repeatUntil: Date
    var repeatUntilOption: RepeatUntilOption
    var repeatUntilCount: Int
    var showRepeatOptions: Bool
    var repeatUnit: String
    var customRepeatCount: Int
}

// Struct for category options
public struct CategoryOptions {
    var selectedCategory: String?
    var selectedColor: CodableColor
}

// Struct for view state
public struct ViewState {
    var showCategoryManagementView: Bool
    var showDeleteActionSheet: Bool
    var showDeleteButtons: Bool
}

// Main view for editing an event
struct EditEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var showEditSheet: Bool
    
    @State private var eventDetails: EventDetails
    @State private var dateOptions: DateOptions
    @State private var categoryOptions: CategoryOptions
    @State private var viewState: ViewState
    
    @State private var showDeleteSeriesAlert = false
    @State private var deleteOption: DeleteOption = .thisEvent
    @State private var showUpdateActionSheet = false
    @State private var shouldDismissEditSheet = false

    // Function to save the event
    let saveEvents: () -> Void

    // Environment object to access shared app data
    @EnvironmentObject var appData: AppData

    init(events: Binding<[Event]>, selectedEvent: Binding<Event?>, showEditSheet: Binding<Bool>, saveEvents: @escaping () -> Void) {
        self._events = events
        self._selectedEvent = selectedEvent
        self._showEditSheet = showEditSheet
        self.saveEvents = saveEvents
        
        let event = selectedEvent.wrappedValue ?? Event(title: "", date: Date(), color: CodableColor(color: .blue))
        self._eventDetails = State(initialValue: EventDetails(title: event.title, selectedEvent: event))
        self._dateOptions = State(initialValue: DateOptions(
            date: event.date,
            endDate: event.endDate ?? event.date,
            showEndDate: event.endDate != nil,
            repeatOption: event.repeatOption,
            repeatUntil: event.repeatUntil ?? Date(),
            repeatUntilOption: event.repeatUntil == nil ? .indefinitely : .onDate,
            repeatUntilCount: event.repeatUntilCount ?? 1,
            showRepeatOptions: event.repeatOption != .never,
            repeatUnit: event.repeatUnit ?? "Days",
            customRepeatCount: event.customRepeatCount ?? 1
        ))
        self._categoryOptions = State(initialValue: CategoryOptions(
            selectedCategory: event.category,
            selectedColor: event.color
        ))
        self._viewState = State(initialValue: ViewState(
            showCategoryManagementView: false,
            showDeleteActionSheet: false,
            showDeleteButtons: true
        ))
    }

    var body: some View {
        NavigationView {
            EventForm(
                eventDetails: $eventDetails,
                dateOptions: $dateOptions,
                categoryOptions: $categoryOptions,
                viewState: $viewState,
                deleteEvent: deleteEvent,
                deleteSeries: { showDeleteSeriesAlert = true }
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
                        if eventDetails.selectedEvent?.repeatOption == .never {
                            applyChanges(to: .thisEvent)
                            showEditSheet = false
                        } else {
                            showUpdateActionSheet = true
                        }
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(categoryOptions.selectedColor.color)
                                    .frame(width: 60, height: 32)
                                Text("Save")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(CustomColorPickerSheet(selectedColor: $categoryOptions.selectedColor, showColorPickerSheet: .constant(false)).contrastColor)
                            }
                        }
                        .opacity(eventDetails.title.isEmpty ? 0.3 : 1.0)
                    }
                    .disabled(eventDetails.title.isEmpty)
                }
            }
            .alert(isPresented: $viewState.showDeleteActionSheet) {
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
                if eventDetails.selectedEvent?.repeatOption != .never {
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
        .onAppear(perform: setupInitialState)
        .alertController(isPresented: $showDeleteSeriesAlert, title: "Delete Series", message: "Are you sure you want to delete all events in this series?", confirmAction: deleteSeries)
        .onChange(of: shouldDismissEditSheet) { newValue in
            if newValue {
                showEditSheet = false
                shouldDismissEditSheet = false
            }
        }
        .onChange(of: categoryOptions.selectedCategory) { newCategory in
            if newCategory == "Birthdays" || newCategory == "Holidays" {
                dateOptions.repeatOption = .yearly
                dateOptions.showRepeatOptions = true
            }
        }
    }

    // Function to delete an event
    func deleteEvent() {
        guard let event = eventDetails.selectedEvent else { return }
        
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
        guard let event = eventDetails.selectedEvent else { return }
        events.removeAll { $0.seriesID == event.seriesID }
        saveEvents()
        showEditSheet = false
    }

    // Function to delete a single event
    func deleteSingleEvent() {
        guard let event = eventDetails.selectedEvent else { return }
        if let index = appData.events.firstIndex(where: { $0.id == event.id }) {
            appData.events.remove(at: index)
            appData.saveEvents()
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
        }
    }

    // Function to get the color of the selected category
    func getCategoryColor() -> Color {
        return categoryOptions.selectedColor.color
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
            if repeatUntil == Calendar.current.date(byAdding: .day, value: calculateRepeatCount(for: event) - 1, to: event.date) {
                dateOptions.repeatUntilOption = .after
            } else if Calendar.current.isDate(repeatUntil, inSameDayAs: event.date) {
                dateOptions.repeatUntilOption = .indefinitely
            } else if repeatUntil > event.date {
                dateOptions.repeatUntilOption = .onDate
            }
        } else {
            dateOptions.repeatUntilOption = .indefinitely
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
            switch dateOptions.repeatUnit {
            case "Days":
                return Calendar.current.dateComponents([.day], from: event.date, to: repeatUntil).day! / dateOptions.customRepeatCount + 1
            case "Weeks":
                return Calendar.current.dateComponents([.weekOfYear], from: event.date, to: repeatUntil).weekOfYear! / dateOptions.customRepeatCount + 1
            case "Months":
                return Calendar.current.dateComponents([.month], from: event.date, to: repeatUntil).month! / dateOptions.customRepeatCount + 1
            case "Years":
                return Calendar.current.dateComponents([.year], from: event.date, to: repeatUntil).year! / dateOptions.customRepeatCount + 1
            default:
                return 1
            }
        }
    }
    
    // Function to apply changes to an event or series of events
    func applyChanges(to option: DeleteOption) {
        guard let event = eventDetails.selectedEvent else { return }

        // Calculate the new duration based on the updated end date
        let newDuration = Calendar.current.dateComponents([.day], from: dateOptions.date, to: dateOptions.endDate).day ?? 0

        switch option {
        case .thisEvent:
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].title = eventDetails.title
                events[index].date = dateOptions.date
                events[index].endDate = dateOptions.showEndDate ? dateOptions.endDate : nil
                events[index].category = categoryOptions.selectedCategory
                events[index].color = categoryOptions.selectedColor
                events[index].repeatOption = dateOptions.repeatOption
                events[index].customRepeatCount = dateOptions.customRepeatCount
                events[index].repeatUnit = dateOptions.repeatUnit
            }
        case .allEvents:
            let repeatingEvents = events.filter { $0.seriesID == event.seriesID }
            let repeatOption = dateOptions.repeatOption

            // Update the selected event
            guard let selectedIndex = events.firstIndex(where: { $0.id == event.id }) else { return }
            events[selectedIndex].title = eventDetails.title
            events[selectedIndex].date = dateOptions.date
            events[selectedIndex].endDate = dateOptions.showEndDate ? dateOptions.endDate : nil
            events[selectedIndex].category = categoryOptions.selectedCategory
            events[selectedIndex].color = categoryOptions.selectedColor
            events[selectedIndex].repeatOption = repeatOption
            events[selectedIndex].customRepeatCount = dateOptions.customRepeatCount
            events[selectedIndex].repeatUnit = dateOptions.repeatUnit

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
                        switch dateOptions.repeatUnit {
                        case "Days":
                            newEventDate = Calendar.current.date(byAdding: .day, value: dateOptions.customRepeatCount, to: previousEventDate)
                        case "Weeks":
                            newEventDate = Calendar.current.date(byAdding: .weekOfYear, value: dateOptions.customRepeatCount, to: previousEventDate)
                        case "Months":
                            newEventDate = Calendar.current.date(byAdding: .month, value: dateOptions.customRepeatCount, to: previousEventDate)
                        case "Years":
                            newEventDate = Calendar.current.date(byAdding: .year, value: dateOptions.customRepeatCount, to: previousEventDate)
                        default:
                            newEventDate = nil
                        }
                    }
                    if let newEventDate = newEventDate, eventCount < 100 {
                        events[eventIndex].title = eventDetails.title
                        events[eventIndex].date = newEventDate
                        events[eventIndex].endDate = dateOptions.showEndDate ? Calendar.current.date(byAdding: .day, value: newDuration, to: newEventDate) : nil
                        events[eventIndex].category = categoryOptions.selectedCategory
                        events[eventIndex].color = categoryOptions.selectedColor
                        events[eventIndex].repeatOption = repeatOption
                        events[eventIndex].customRepeatCount = dateOptions.customRepeatCount
                        events[eventIndex].repeatUnit = dateOptions.repeatUnit
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
                        switch dateOptions.repeatUnit {
                        case "Days":
                            newEventDate = Calendar.current.date(byAdding: .day, value: -dateOptions.customRepeatCount, to: nextEventDate)
                        case "Weeks":
                            newEventDate = Calendar.current.date(byAdding: .weekOfYear, value: -dateOptions.customRepeatCount, to: nextEventDate)
                        case "Months":
                            newEventDate = Calendar.current.date(byAdding: .month, value: -dateOptions.customRepeatCount, to: nextEventDate)
                        case "Years":
                            newEventDate = Calendar.current.date(byAdding: .year, value: -dateOptions.customRepeatCount, to: nextEventDate)
                        default:
                            newEventDate = nil
                        }
                    }
                    if let newEventDate = newEventDate, eventCount < 100 {
                        events[eventIndex].title = eventDetails.title
                        events[eventIndex].date = newEventDate
                        events[eventIndex].endDate = dateOptions.showEndDate ? Calendar.current.date(byAdding: .day, value: newDuration, to: newEventDate) : nil
                        events[eventIndex].category = categoryOptions.selectedCategory
                        events[eventIndex].color = categoryOptions.selectedColor
                        events[eventIndex].repeatOption = repeatOption
                        events[eventIndex].customRepeatCount = dateOptions.customRepeatCount
                        events[eventIndex].repeatUnit = dateOptions.repeatUnit
                        eventCount += 1
                    } else {
                        events.remove(at: eventIndex)
                    }
                }
            }
        }
        
        // Check if the event will be included in the daily notification for the date of the event
        let calendar = Calendar.current
        let eventDayStart = calendar.startOfDay(for: dateOptions.date)
        let eventDayEnd = calendar.date(byAdding: .day, value: 1, to: eventDayStart)!
        
        let eventsOnEventDay = events.filter { event in
            let eventStart = calendar.startOfDay(for: event.date)
            return eventStart >= eventDayStart && eventStart < eventDayEnd
        }
        
        if eventsOnEventDay.contains(where: { $0.id == event.id }) {
            print("The event '\(eventDetails.title)' will be included in the daily notification for \(dateOptions.date).")
        } else {
            print("The event '\(eventDetails.title)' will NOT be included in the daily notification for \(dateOptions.date).")
        }

        appData.objectWillChange.send() // Notify observers of changes
        saveEvents()
        showEditSheet = false
    }

    private func setupInitialState() {
        if let event = selectedEvent {
            eventDetails.title = event.title
            dateOptions.date = event.date
            dateOptions.endDate = event.endDate ?? event.date
            dateOptions.showEndDate = event.endDate != nil
            
            // Check if the event has its own repeat options, if not, use the category's
            if event.repeatOption == .never, let category = appData.categories.first(where: { $0.name == event.category }) {
                dateOptions.repeatOption = category.repeatOption
                dateOptions.repeatUntil = category.repeatUntil
                dateOptions.repeatUntilOption = category.repeatUntilOption
                dateOptions.repeatUntilCount = category.repeatUntilCount
                dateOptions.showRepeatOptions = category.repeatOption != .never
                dateOptions.repeatUnit = category.repeatUnit
                dateOptions.customRepeatCount = category.customRepeatCount
            } else {
                dateOptions.repeatOption = event.repeatOption
                dateOptions.repeatUntil = event.repeatUntil ?? Date()
                dateOptions.repeatUntilOption = event.repeatUntil == nil ? .indefinitely : .onDate
                dateOptions.repeatUntilCount = event.repeatUntilCount ?? 1
                dateOptions.showRepeatOptions = event.repeatOption != .never
                dateOptions.repeatUnit = event.repeatUnit ?? "Days"
                dateOptions.customRepeatCount = event.customRepeatCount ?? 1
            }
            
            categoryOptions.selectedCategory = event.category
            categoryOptions.selectedColor = event.color
        }
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