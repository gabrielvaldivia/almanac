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
                repeatIndefinitely = event.repeatUntil == nil // Adjust logic
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
                            Toggle("Repeat Indefinitely", isOn: $repeatIndefinitely)
                                .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
                            if !repeatIndefinitely {
                                DatePicker("Repeat Until", selection: $repeatUntil, displayedComponents: .date)
                                    .datePickerStyle(DefaultDatePickerStyle())
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
                            showDeleteActionSheet = true
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
                    repeatIndefinitely = event.repeatUntil == nil // Adjust logic
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
            events.removeAll { $0.id == event.id || $0.repeatOption == event.repeatOption }
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

enum DeleteOption {
    case thisEvent
    case thisAndUpcoming
    case allEvents
}
