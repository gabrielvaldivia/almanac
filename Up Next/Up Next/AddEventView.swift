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
import Combine // Add this import

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
    @State private var repeatOption: RepeatOption = .never // Changed from .none to .never
    @State private var repeatUntil: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely // New state variable
    @State private var repeatCount: Int = 1 // New state variable for number of repetitions
    @State private var showRepeatOptions: Bool = false // New state variable to show/hide repeat options
    @StateObject private var keyboardResponder = KeyboardResponder()
    @State private var isNameFieldFocused: Bool = false // New state variable
    @State private var showAddCategorySheet: Bool = false // New state variable
    @State private var newCategoryName: String = "" // New state variable
    @State private var newCategoryColor: Color = .blue // New state variable

    var body: some View {
        NavigationView {
            ScrollView { // Wrap the content in a ScrollView
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
                            .background(isNameFieldFocused ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground)) // Change background color based on focus
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isNameFieldFocused ? getCategoryColor() : Color.clear, lineWidth: 1) // Add stroke based on focus
                            )
                            .shadow(color: isNameFieldFocused ? getCategoryColor().opacity(0.2) : Color.clear, radius: 4) // Add subtle glow
                        }
                    }
                    .padding (.horizontal)
                    
                    
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
                                        .fill(showEndDate ? getCategoryColor() : Color.gray.opacity(0.2)) // Change background color based on state
                                        .frame(width: 36, height: 36)
                                    Image(systemName: showEndDate ? "calendar.badge.minus" : "calendar.badge.plus")
                                        .font(.system(size: 16, weight: .semibold)) // Smaller and thicker icon
                                        .foregroundColor(showEndDate ? .white : .gray) // Change icon color based on state
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
                                        .fill(repeatOption == .never ? Color.gray.opacity(0.2) : getCategoryColor()) // Change background color based on state
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "repeat")
                                        .font(.system(size: 16, weight: .semibold)) // Smaller and thicker icon
                                        .foregroundColor(repeatOption == .never ? .gray : .white) // Change icon color based on state
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
                                            .foregroundColor(repeatUntilOption == .indefinitely ? getCategoryColor() : .gray) // Conditional color
                                        Text("Repeat \(repeatOption.rawValue.lowercased()) indefinitely") // Updated text
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
                                                .foregroundColor(repeatUntilOption == .onDate ? getCategoryColor() : .gray) // Conditional color
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
                                            .onChange(of: repeatUntil) { newDate in
                                                print("Selected date: \(dateFormatter.string(from: newDate))")
                                            }
                                    }
                                }

                                HStack (alignment: .center) {
                                    Button(action: { repeatUntilOption = .after }) {
                                    HStack {
                                        Image(systemName: repeatUntilOption == .after ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 24))
                                            .fontWeight(.light)
                                            .foregroundColor(repeatUntilOption == .after ? getCategoryColor() : .gray) // Conditional color
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
                                                .frame(height: 36)
                                                .padding(.vertical,0)
                                                .multilineTextAlignment(.center)
                                            Text(getRepeatCadenceText())
                                            Spacer()
                                            Stepper("", value: $repeatCount, in: 1...100)
                                            .frame(height: 36)
                                            .padding(.vertical,0)
                                        }
                                        
                                    }
                                }
                            }
                        }
                    }
                    .padding (.horizontal)
                    
                    
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
                                    selectedCategory = nil // Ensure no category is selected
                                    showAddCategorySheet = true // Show the add category sheet
                                    newCategoryName = ""
                                    newCategoryColor = Color(red: Double.random(in: 0.1...0.9), green: Double.random(in: 0.1...0.9), blue: Double.random(in: 0.1...0.9)) // Ensure middle range color
                                }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("New Category")
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(20)
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        HStack {
                            Toggle(isOn: $notificationsEnabled) {
                                Text("Notify me")
                                    .fontWeight(.semibold) // Make the text bold
                                    .foregroundColor(.gray) // Set text color to light gray
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
                            .opacity(newEventTitle.isEmpty ? 0.3 : 1.0) // Adjust opacity based on title
                        }
                        .disabled(newEventTitle.isEmpty) // Disable the button if newEventTitle is empty
                    }
                }
            }
            .onAppear {
                if selectedCategory == nil {
                    selectedCategory = appData.defaultCategory.isEmpty ? "Work" : appData.defaultCategory
                }
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
                ) // Present the AddCategoryView as a sheet
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
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
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
            maxRepetitions = 100 // Set a reasonable upper limit to prevent crashes
        case .after:
            maxRepetitions = repeatCount
        case .onDate:
            maxRepetitions = 100 // Set a reasonable upper limit to prevent crashes
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
            // print("Saved events: \(events)")
        } else {
            print("Failed to encode events.")
        }
    }
    
    // Helper function to get the color of the selected category
    func getCategoryColor() -> Color {
        if let selectedCategory = selectedCategory,
           let category = appData.categories.first(where: { $0.name == selectedCategory }) {
            return category.color // Assuming category.color is of type Color
        }
        return Color.blue // Default color if no category is selected
    }
    
    func getRepeatCadenceText() -> String {
        let cadence: String
        switch repeatOption {
        case .daily:
            cadence = repeatCount == 1 ? "day" : "days"
        case .weekly:
            cadence = repeatCount == 1 ? "week" : "weeks"
        case .monthly:
            cadence = repeatCount == 1 ? "month" : "months"
        case .yearly:
            cadence = repeatCount == 1 ? "year" : "years"
        case .never:
            cadence = repeatCount == 1 ? "time" : "times"
        }
        return cadence
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





