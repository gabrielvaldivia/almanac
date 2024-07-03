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
                repeatOption = event.repeatOption
                repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
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
                            Button("Remove End Date") {
                                showEndDate = false
                                newEventEndDate = Date()
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("Add End Date") {
                                showEndDate = true
                                newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date()
                            }
                            .foregroundColor(getCategoryColor()) // Change color based on category
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
                            if let event = selectedEvent {
                                deleteEvent(at: event)
                            }
                            showEditSheet = false
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                if let event = selectedEvent {
                    notificationsEnabled = event.notificationsEnabled
                    repeatOption = event.repeatOption
                    repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                }
            }
    }

    func deleteEvent(at event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
            saveEvents()
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
            events[index].repeatOption = repeatOption
            events[index].repeatUntil = repeatOption != .never ? repeatUntil : nil
            saveEvents()
            if events[index].notificationsEnabled {
                appData.scheduleNotification(for: events[index])
            } else {
                appData.removeNotification(for: events[index])
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify UpNextWidget to reload
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget") // Notify NextEventWidget to reload
        }
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
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
        } else {
            print("Failed to encode events.")
        }
    }
    
    func getCategoryColor() -> Color {
        if let selectedCategory = selectedCategory,
           let category = appData.categories.first(where: { $0.name == selectedCategory }) {
            return category.color // Assuming category.color is of type Color
        }
        return Color.blue // Default color if no category is selected
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
            selectedColor: .constant(CodableColor(color: .black)),
            notificationsEnabled: .constant(true),
            saveEvent: {}
        )
        .environmentObject(AppData())
    }
}
