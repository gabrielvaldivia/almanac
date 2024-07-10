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

enum DeleteOption {
    case thisEvent
    case thisAndUpcoming
    case allEvents
}

struct EditEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event? {
        didSet {
            if let event = selectedEvent {
                notificationsEnabled = event.notificationsEnabled
                repeatOption = event.repeatOption
                repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                repeatIndefinitely = event.repeatUntil == nil // Adjust logic
                updateRepeatUntilOption(for: event)
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
    @Binding var notificationsEnabled: Bool
    @State private var repeatOption: RepeatOption = .never
    @State private var repeatUntil: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely
    @State private var repeatCount: Int = 1
    @State private var repeatIndefinitely: Bool = false // New state variable
    @State private var showDeleteActionSheet = false
    @State private var deleteOption: DeleteOption = .thisEvent
    @State private var showCategoryManagementView = false
    @State private var showUpdateActionSheet = false
    @State private var showDeleteSeriesAlert = false // New state variable
    var saveEvent: () -> Void
    @EnvironmentObject var appData: AppData

    var body: some View {
        NavigationView {
            EventForm(
                newEventTitle: $newEventTitle,
                newEventDate: $newEventDate,
                newEventEndDate: $newEventEndDate,
                showEndDate: $showEndDate,
                selectedCategory: $selectedCategory,
                selectedColor: $selectedColor,
                notificationsEnabled: $notificationsEnabled,
                repeatOption: $repeatOption,
                repeatUntil: $repeatUntil,
                repeatUntilOption: $repeatUntilOption,
                repeatCount: $repeatCount,
                showCategoryManagementView: $showCategoryManagementView,
                showDeleteActionSheet: $showDeleteActionSheet, // Pass the binding
                selectedEvent: $selectedEvent, // Pass the binding
                deleteEvent: deleteEvent, // Pass the function
                deleteSeries: { showDeleteSeriesAlert = true } // Show alert
            )
            .environmentObject(appData)
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                        showUpdateActionSheet = true
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedColor.color)
                                    .frame(width: 60, height: 32)
                                Text("Save")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
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
            .alert(isPresented: $showUpdateActionSheet) {
                if selectedEvent?.repeatOption != .never {
                    return Alert(
                        title: Text("Update Event"),
                        message: Text("Do you want to apply the changes to this event only or all events in the series?"),
                        primaryButton: .default(Text("This Event Only")) {
                            applyChanges(to: .thisEvent)
                        },
                        secondaryButton: .default(Text("All Events in Series")) {
                            applyChanges(to: .allEvents)
                        }
                    )
                } else {
                    return Alert(
                        title: Text("Update Event"),
                        message: Text("Do you want to save the changes?"),
                        primaryButton: .default(Text("Save")) {
                            applyChanges(to: .thisEvent)
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .onAppear {
            if let event = selectedEvent {
                notificationsEnabled = event.notificationsEnabled
                repeatOption = event.repeatOption
                repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                repeatIndefinitely = event.repeatUntil == nil
                updateRepeatUntilOption(for: event)
            }
        }
        .alertController(isPresented: $showDeleteSeriesAlert, title: "Delete Series", message: "Are you sure you want to delete all events in this series?", confirmAction: deleteSeries)
    }

    func deleteEvent() {
        guard let event = selectedEvent else { return }
        
        switch deleteOption {
        case .thisEvent:
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events.remove(at: index)
            }
        case .thisAndUpcoming:
            events.removeAll { $0.id == event.id || ($0.title == event.title && $0.category == event.category && $0.date >= event.date) }
        case .allEvents:
            events.removeAll { $0.title == event.title && $0.category == event.category }
        }
        
        saveEvents()
        showEditSheet = false
    }

    func deleteSeries() {
        guard let event = selectedEvent else { return }
        events.removeAll { $0.title == event.title && $0.category == event.category }
        saveEvents()
        showEditSheet = false
    }

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

    func getCategoryColor() -> Color {
        return selectedColor.color
    }

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
    
    func calculateRepeatUntilDate(for option: RepeatOption, from startDate: Date, count: Int) -> Date? {
        switch option {
        case .never:
            return nil
        case .daily:
            return Calendar.current.date(byAdding: .day, value: count - 1, to: startDate)
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: count - 1, to: startDate)
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: count - 1, to: startDate)
        case .yearly:
            return Calendar.current.date(byAdding: .year, value: count - 1, to: startDate)
        }
    }
    
    func generateRepeatingEvents(for event: Event) -> [Event] {
        var repeatingEvents = [Event]()
        var currentEvent = event
        repeatingEvents.append(currentEvent)
        
        var repetitionCount = 1
        let maxRepetitions: Int
        
        switch repeatUntilOption {
        case .indefinitely:
            maxRepetitions = 100
        case .after:
            maxRepetitions = repeatCount
        case .onDate:
            maxRepetitions = 100
        }
        
        while let nextDate = getNextRepeatDate(for: currentEvent), 
              nextDate <= (event.repeatUntil ?? Date.distantFuture), 
              repetitionCount < maxRepetitions {
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
            repetitionCount += 1
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
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM, d, yyyy"
        return formatter
    }

    private func updateRepeatUntilOption(for event: Event) {
        if let repeatUntil = event.repeatUntil {
            if Calendar.current.isDate(repeatUntil, inSameDayAs: event.date) {
                repeatUntilOption = .indefinitely
            } else if repeatUntil > event.date {
                repeatUntilOption = .onDate
            } else {
                repeatUntilOption = .after
            }
        } else {
            repeatUntilOption = .indefinitely
        }
    }
    
    func applyChanges(to option: DeleteOption) {
        guard let selectedEvent = selectedEvent else { return }

        switch option {
        case .thisEvent:
            if let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
                events[index].title = newEventTitle
                events[index].date = newEventDate
                events[index].endDate = showEndDate ? newEventEndDate : nil
                events[index].category = selectedCategory
                events[index].color = selectedColor
                events[index].notificationsEnabled = notificationsEnabled
            }
        case .thisAndUpcoming:
            // Handle thisAndUpcoming if needed, otherwise you can leave it empty or add a comment
            break
        case .allEvents:
            let repeatingEvents = events.filter { $0.title == selectedEvent.title && $0.category == selectedEvent.category }
            let duration = Calendar.current.dateComponents([.day], from: newEventDate, to: newEventEndDate).day ?? 0
            let originalStartDate = selectedEvent.date
            let newStartDate = newEventDate
            let dateDifference = Calendar.current.dateComponents([.day], from: originalStartDate, to: newStartDate).day ?? 0
            let repeatOption = selectedEvent.repeatOption

            for (index, event) in repeatingEvents.enumerated() {
                events[index].title = newEventTitle
                events[index].category = selectedCategory
                events[index].color = selectedColor
                events[index].notificationsEnabled = notificationsEnabled

                if index == 0 {
                    events[index].date = newEventDate
                    events[index].endDate = showEndDate ? newEventEndDate : nil
                } else {
                    let previousEventDate = events[index - 1].date
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
                    }
                    if let newEventDate = newEventDate {
                        events[index].date = newEventDate
                        events[index].endDate = showEndDate ? Calendar.current.date(byAdding: .day, value: duration, to: newEventDate) : nil
                    }
                }
            }

            // Adjust past events
            for (index, event) in repeatingEvents.enumerated().reversed() {
                if index == 0 { continue }
                let nextEventDate = events[index].date
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
                }
                if let newEventDate = newEventDate {
                    events[index - 1].date = newEventDate
                    events[index - 1].endDate = showEndDate ? Calendar.current.date(byAdding: .day, value: duration, to: newEventDate) : nil
                }
            }
        }
        saveEvents()
        showEditSheet = false
    }
}

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

extension View {
    func alertController(isPresented: Binding<Bool>, title: String, message: String, confirmAction: @escaping () -> Void) -> some View {
        self.modifier(AlertControllerModifier(isPresented: isPresented, title: title, message: message, confirmAction: confirmAction))
    }
}