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
                        .datePickerStyle(DefaultDatePickerStyle())
                    if showEndDate {
                        DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                            .datePickerStyle(DefaultDatePickerStyle())
                    }
                    Toggle("Multi-Day", isOn: $showEndDate)
                        .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
                }
                Section() {
                    Menu {
                        ForEach(RepeatOption.allCases, id: \.self) { option in
                            Button(action: {
                                repeatOption = option
                            }) {
                                Text(option.rawValue)
                                    .foregroundColor(option == repeatOption ? .gray : .primary)
                            }
                        }
                    } label: {
                        HStack {
                            Text("Repeat")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(repeatOption.rawValue)
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.gray)
                                .font(.footnote)
                        }
                    }

                    if repeatOption != .never {
                        Menu {
                            Button(action: {
                                repeatUntilOption = .indefinitely
                            }) {
                                Text("Never")
                                    .foregroundColor(repeatUntilOption == .indefinitely ? .gray : .primary)
                            }
                            Button(action: {
                                repeatUntilOption = .after
                            }) {
                                Text("After")
                                    .foregroundColor(repeatUntilOption == .after ? .gray : .primary)
                            }
                            Button(action: {
                                repeatUntilOption = .onDate
                            }) {
                                Text("On")
                                    .foregroundColor(repeatUntilOption == .onDate ? .gray : .primary)
                            }
                        } label: {
                            HStack {
                                Text("End Repeat")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(repeatUntilOption.rawValue)
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.gray)
                                    .font(.footnote)
                            }
                        }

                        if repeatUntilOption == .after {
                            HStack {
                                TextField("", value: $repeatCount, formatter: NumberFormatter())
                                    .keyboardType(.numberPad)
                                    .frame(width: 24)
                                    .multilineTextAlignment(.center)
                                Stepper(value: $repeatCount, in: 1...100) {
                                    Text(" times")
                                }
                            }
                        } else if repeatUntilOption == .onDate {
                            DatePicker("Date", selection: $repeatUntil, displayedComponents: .date)
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
                        .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
                }
            }
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
                        saveEvent()
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(getCategoryColor())
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
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete Event") {
                        if selectedEvent?.repeatOption != .never {
                            showDeleteActionSheet = true
                        } else {
                            deleteEvent()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .actionSheet(isPresented: $showDeleteActionSheet) {
                ActionSheet(
                    title: Text("Delete Event"),
                    message: Text("Are you sure you want to delete this event?"),
                    buttons: [
                        .destructive(Text("Delete this event")) {
                            deleteOption = .thisEvent
                            deleteEvent()
                        },
                        .destructive(Text("Delete this and all upcoming events")) {
                            deleteOption = .thisAndUpcoming
                            deleteEvent()
                        },
                        .destructive(Text("Delete all events in this series")) {
                            deleteOption = .allEvents
                            deleteEvent()
                        },
                        .cancel()
                    ]
                )
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
    }

    func deleteEvent() {
        guard let event = selectedEvent else { return }
        
        switch deleteOption {
        case .thisEvent:
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events.remove(at: index)
            }
        case .thisAndUpcoming:
            events.removeAll { $0.id == event.id || ($0.repeatOption == event.repeatOption && $0.date >= event.date) }
        case .allEvents:
            events.removeAll { $0.title == event.title && $0.category == event.category }
        }
        
        saveEvents()
        showEditSheet = false
    }

    func getCategoryColor() -> Color {
        if let selectedCategory = selectedCategory,
           let category = appData.categories.first(where: { $0.name == selectedCategory }) {
            return category.color // Assuming category.color is of type Color
        }
        return Color.blue // Default color if no category is selected
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
}
