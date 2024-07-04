//
//  Events.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UserNotifications
import WidgetKit
import Combine

struct AddEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showAddEventSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor
    @Binding var notificationsEnabled: Bool
    @EnvironmentObject var appData: AppData
    @State private var repeatOption: RepeatOption = .never
    @State private var repeatUntil: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely
    @State private var repeatCount: Int = 1
    @State private var showRepeatOptions: Bool = false
    @StateObject private var keyboardResponder = KeyboardResponder()
    @FocusState private var isNameFieldFocused: Bool // Change to FocusState
    @State private var showAddCategorySheet: Bool = false
    @State private var newCategoryName: String = ""
    @State private var newCategoryColor: Color = .blue

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    // Name Section
                    VStack {
                        HStack {
                            Text("Name")
                                .font(.headline)
                                .padding(.top)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        
                        HStack {
                            TextField("Title", text: $newEventTitle, onEditingChanged: { isEditing in
                                isNameFieldFocused = isEditing
                            })
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .background(isNameFieldFocused ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isNameFieldFocused ? getCategoryColor() : Color.clear, lineWidth: 1)
                            )
                            .shadow(color: isNameFieldFocused ? getCategoryColor().opacity(0.2) : Color.clear, radius: 4)
                            .focused($isNameFieldFocused) // Use FocusState binding
                        }
                    }
                    .padding(.horizontal)
                    
                    // Date Section
                    VStack {
                        HStack {
                            Text("Date")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.top)
                            Spacer()
                        }
                        
                        HStack {
                            DatePicker("", selection: $newEventDate, displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle())
                                .labelsHidden()
                            
                            if showEndDate {
                                DatePicker("", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                    .datePickerStyle(DefaultDatePickerStyle())
                                    .labelsHidden()
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showEndDate.toggle()
                                if !showEndDate {
                                    newEventEndDate = Date()
                                } else {
                                    newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date()
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(showEndDate ? getCategoryColor() : Color.gray.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: showEndDate ? "calendar.badge.minus" : "calendar.badge.plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(showEndDate ? .white : .gray)
                                }
                            }
                            
                            Menu {
                                Picker("Repeat", selection: $repeatOption) {
                                    ForEach(RepeatOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(repeatOption == .never ? Color.gray.opacity(0.2) : getCategoryColor())
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "repeat")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(repeatOption == .never ? .gray : .white)
                                }
                            }
                        }
                        .padding(.horizontal, 0)
                        
                        if repeatOption != .never {
                            VStack(alignment: .leading) {
                                Button(action: { repeatUntilOption = .indefinitely }) {
                                    HStack {
                                        Image(systemName: repeatUntilOption == .indefinitely ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 24))
                                            .fontWeight(.light)
                                            .foregroundColor(repeatUntilOption == .indefinitely ? getCategoryColor() : .gray)
                                        Text("Repeat \(repeatOption.rawValue.lowercased()) indefinitely")
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 36)
                                    .padding(.top, 10)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                HStack {
                                    Button(action: { repeatUntilOption = .onDate }) {
                                        HStack {
                                            Image(systemName: repeatUntilOption == .onDate ? "largecircle.fill.circle" : "circle")
                                                .font(.system(size: 24))
                                                .fontWeight(.light)
                                                .foregroundColor(repeatUntilOption == .onDate ? getCategoryColor() : .gray)
                                            Text("Repeat \(repeatOption.rawValue.lowercased()) until")
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: 36)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Spacer()
                                    if repeatUntilOption == .onDate {
                                        DatePicker("", selection: $repeatUntil, displayedComponents: .date)
                                            .datePickerStyle(DefaultDatePickerStyle())
                                            .labelsHidden()
                                    }
                                }
                                
                                HStack {
                                    Button(action: { repeatUntilOption = .after }) {
                                        HStack {
                                            Image(systemName: repeatUntilOption == .after ? "largecircle.fill.circle" : "circle")
                                                .font(.system(size: 24))
                                                .fontWeight(.light)
                                                .foregroundColor(repeatUntilOption == .after ? getCategoryColor() : .gray)
                                            Text("End after")
                                        }
                                        .frame(alignment: .leading)
                                        .frame(height: 36)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
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
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Category Section
                    VStack {
                        HStack {
                            Text("Category")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.top)
                                .padding(.horizontal)
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(appData.categories, id: \.name) { category in
                                    Text(category.name)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category.name ? getCategoryColor() : Color.gray.opacity(0.15))
                                        .cornerRadius(20)
                                        .foregroundColor(selectedCategory == category.name ? .white : .primary)
                                        .onTapGesture {
                                            selectedCategory = category.name
                                        }
                                }
                                // New category pill
                                Button(action: {
                                    selectedCategory = nil
                                    showAddCategorySheet = true
                                    newCategoryName = ""
                                    newCategoryColor = Color(red: Double.random(in: 0.1...0.9), green: Double.random(in: 0.1...0.9), blue: Double.random(in: 0.1...0.9))
                                }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("New Category")
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                    }
                    
                    // Notification Section
                    HStack {
                        Toggle(isOn: $notificationsEnabled) {
                            Text("Notify me")
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button(action: {
                        showAddEventSheet = false
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
                        saveNewEvent()
                        showAddEventSheet = false
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(getCategoryColor())
                                    .frame(width: 60, height: 32)
                                Text("Add")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(newEventTitle.isEmpty ? 0.3 : 1.0)
                    }
                    .disabled(newEventTitle.isEmpty)
                }
            }
            .onAppear {
                if selectedCategory == nil {
                    selectedCategory = appData.defaultCategory.isEmpty ? "Work" : appData.defaultCategory
                }
                isNameFieldFocused = true // Focus the TextField when the sheet appears
            }
            .sheet(isPresented: $showAddCategorySheet, onDismiss: {
                if !newCategoryName.isEmpty {
                    selectedCategory = newCategoryName
                }
            }) {
                AddCategoryView(
                    newCategoryName: $newCategoryName,
                    newCategoryColor: $newCategoryColor,
                    showingAddCategorySheet: $showAddCategorySheet,
                    appData: appData
                )
            }
        }
    }

    func deleteEvent(at event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
        }
    }

    func saveNewEvent() {
        let repeatUntilDate: Date?
        switch repeatUntilOption {
        case .indefinitely:
            repeatUntilDate = nil
        case .after:
            repeatUntilDate = calculateRepeatUntilDate(for: repeatOption, from: newEventDate, count: repeatCount)
        case .onDate:
            repeatUntilDate = repeatUntil
        }

        let newEvent = Event(
            title: newEventTitle,
            date: newEventDate,
            endDate: showEndDate ? newEventEndDate : nil,
            color: selectedColor,
            category: selectedCategory,
            notificationsEnabled: notificationsEnabled,
            repeatOption: repeatOption,
            repeatUntil: repeatUntilDate
        )

        // Remove existing events in the series if editing an existing event
        if let selectedEvent = selectedEvent {
            events.removeAll { $0.id == selectedEvent.id || $0.repeatOption == selectedEvent.repeatOption }
        }

        // Create new events based on the repeat options
        let newEvents = generateRepeatingEvents(for: newEvent)
        events.append(contentsOf: newEvents)

        saveEvents()
        if newEvent.notificationsEnabled {
            appData.scheduleNotification(for: newEvent)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
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
        
        print("Generating repeating events for \(event.title)")
        print("Repeat option: \(event.repeatOption)")
        print("Repeat until: \(String(describing: event.repeatUntil))")
        print("Max repetitions: \(maxRepetitions)")
        
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
            
            print("Added event on \(nextDate)")
        }
        
        print("Generated \(repeatingEvents.count) events")
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
        } else {
            print("Failed to encode events.")
        }
    }
    
    // Helper function to get the color of the selected category
    func getCategoryColor() -> Color {
        if let selectedCategory = selectedCategory,
           let category = appData.categories.first(where: { $0.name == selectedCategory }) {
            return category.color
        }
        return Color.blue
    }
}

enum RepeatUntilOption: String, CaseIterable {
    case indefinitely = "Indefinitely"
    case after = "After"
    case onDate = "On"
}

// Custom date formatter
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM, d, yyyy"
    return formatter
}

final class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0
    private var cancellable: AnyCancellable?

    init() {
        cancellable = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification))
            .compactMap { notification in
                notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            }
            .map { rect in
                rect.height
            }
            .assign(to: \.currentHeight, on: self)
    }

    deinit {
        cancellable?.cancel()
    }
}





