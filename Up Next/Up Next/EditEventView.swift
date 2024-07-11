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
                repeatIndefinitely = event.repeatUntil == nil
                repeatCount = calculateRepeatCount(for: event)
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
    @State private var repeatIndefinitely: Bool = false
    @State private var showDeleteActionSheet = false
    @State private var deleteOption: DeleteOption = .thisEvent
    @State private var showCategoryManagementView = false
    @State private var showUpdateActionSheet = false
    @State private var showDeleteSeriesAlert = false
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
                showDeleteActionSheet: $showDeleteActionSheet,
                selectedEvent: $selectedEvent,
                deleteEvent: deleteEvent,
                deleteSeries: { showDeleteSeriesAlert = true }
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
                        if selectedEvent?.repeatOption == .never {
                            applyChanges(to: .thisEvent)
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
            .actionSheet(isPresented: $showUpdateActionSheet) {
                if selectedEvent?.repeatOption != .never {
                    return ActionSheet(
                        title: Text("Update Event"),
                        message: Text("Do you want to apply the changes to this event only or all events in the series?"),
                        buttons: [
                            .default(Text("This Event Only")) {
                                applyChanges(to: .thisEvent)
                            },
                            .default(Text("All Events in Series")) {
                                applyChanges(to: .allEvents)
                            },
                            .cancel()
                        ]
                    )
                } else {
                    applyChanges(to: .thisEvent)
                    return ActionSheet(title: Text(""), message: Text(""), buttons: [])
                }
            }
        }
        .onAppear {
            if let event = selectedEvent {
                notificationsEnabled = event.notificationsEnabled
                repeatOption = event.repeatOption
                repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                repeatIndefinitely = event.repeatUntil == nil
                repeatCount = calculateRepeatCount(for: event)
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
        case .allEvents:
            events.removeAll { $0.title == event.title && $0.category == event.category }
        }
        
        saveEvents()
        showEditSheet = false
    }

    func deleteSeries() {
        guard let event = selectedEvent else { return }
        events.removeAll { $0.seriesID == event.seriesID }
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
        let seriesID = UUID()
        currentEvent.seriesID = seriesID
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
        
        let duration = Calendar.current.dateComponents([.day], from: event.date, to: event.endDate ?? event.date).day ?? 0
        
        while let nextDate = getNextRepeatDate(for: currentEvent), 
              nextDate <= (event.repeatUntil ?? Date.distantFuture), 
              repetitionCount < maxRepetitions {
            currentEvent = Event(
                title: event.title,
                date: nextDate,
                endDate: showEndDate ? Calendar.current.date(byAdding: .day, value: duration, to: nextDate) : nil,
                color: event.color,
                category: event.category,
                notificationsEnabled: event.notificationsEnabled,
                repeatOption: event.repeatOption,
                repeatUntil: event.repeatUntil,
                seriesID: seriesID
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
        }
    }
    
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
                events[index].notificationsEnabled = notificationsEnabled
                events[index].repeatOption = repeatOption
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
            events[selectedIndex].notificationsEnabled = notificationsEnabled
            events[selectedIndex].repeatOption = repeatOption

            // Update future events
            var eventCount = 1
            for (index, event) in repeatingEvents.enumerated() {
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
                    }
                    if let newEventDate = newEventDate, eventCount < 100 {
                        events[eventIndex].date = newEventDate
                        events[eventIndex].endDate = showEndDate ? Calendar.current.date(byAdding: .day, value: newDuration, to: newEventDate) : nil
                        eventCount += 1
                    } else {
                        events.remove(at: eventIndex)
                    }
                }
            }

            // Update past events
            eventCount = 1
            for (index, event) in repeatingEvents.enumerated().reversed() {
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
                    }
                    if let newEventDate = newEventDate, eventCount < 100 {
                        events[eventIndex].date = newEventDate
                        events[eventIndex].endDate = showEndDate ? Calendar.current.date(byAdding: .day, value: newDuration, to: newEventDate) : nil
                        eventCount += 1
                    } else {
                        events.remove(at: eventIndex)
                    }
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
