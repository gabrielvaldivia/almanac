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

// Main view for adding a new event
struct AddEventView: View {
    // Bindings to parent view's state
    @Binding var events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showAddEventSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor // Use CodableColor to store color

    // Environment object to access shared app data
    @EnvironmentObject var appData: AppData

    // Focus state for managing keyboard focus
    @FocusState private var isTitleFocused: Bool // Add this line to manage focus state

    // State variables for repeat options
    @State private var repeatOption: RepeatOption = .never // Changed from .none to .never
    @State private var repeatUntil: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely // New state variable
    @State private var repeatUntilCount: Int = 1 // New state variable for number of repetitions

    // State variables for UI management
    @State private var showCategoryManagementView = false // Add this state variable
    @State private var showDeleteActionSheet = false // Add this state variable
    @State private var showRepeatOptions = false // Set this to false by default
    @State private var repeatUnit: String = "Days" // Add this line
    @State private var customRepeatCount: Int = 1 // Add this line

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
                isTitleFocused: _isTitleFocused, // Pass FocusState directly
                deleteEvent: {}, // Remove deleteEvent functionality
                deleteSeries: {}, // Remove deleteSeries functionality
                showDeleteButtons: false, // Do not show delete buttons
                showRepeatOptions: $showRepeatOptions, // Pass the binding
                repeatUnit: $repeatUnit,
                customRepeatCount: $customRepeatCount // Add this line
            )
            .environmentObject(appData)
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar with cancel and save buttons
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
                                    .fill(selectedColor.color)
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
        }
        .sheet(isPresented: $showCategoryManagementView) {
            // Category management view
            NavigationView {
                CategoriesView()
                    .environmentObject(appData)
            }
            .presentationDetents([.medium, .large], selection: .constant(.medium))
        }
        .onAppear {
            // Set initial focus and default values
            isTitleFocused = true
            selectedColor = CodableColor(color: .blue) // Set default color to blue
            if selectedCategory == nil {
                selectedCategory = nil // Set default category to nil
            }
        }
        .onDisappear {
            // Clear focus when view disappears
            isTitleFocused = false
        }
    }

    // Function to save the new event
    func saveNewEvent() {
        let repeatUntilDate: Date?
        switch repeatUntilOption {
        case .indefinitely:
            repeatUntilDate = nil
        case .after:
            repeatUntilDate = calculateRepeatUntilDate(for: repeatOption, from: newEventDate, count: repeatUntilCount, repeatUnit: repeatUnit)
        case .onDate:
            repeatUntilDate = repeatUntil
        }

        let newEvent = Event(
            title: newEventTitle,
            date: newEventDate,
            endDate: showEndDate ? newEventEndDate : nil,
            color: selectedColor,
            category: selectedCategory,
            repeatOption: repeatOption,
            repeatUntil: repeatUntilDate,
            customRepeatCount: customRepeatCount,
            repeatUnit: repeatUnit,
            repeatUntilCount: repeatUntilCount
        )

        let newEvents = generateRepeatingEvents(for: newEvent, repeatUntilOption: repeatUntilOption, showEndDate: showEndDate)
        events.append(contentsOf: newEvents)
        saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
        appData.objectWillChange.send() // Notify observers of changes
        appData.scheduleDailyNotification() // Reschedule notification when an event is added
    }

    // Function to save events to UserDefaults
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
        return selectedColor.color
    }
    
}

// Helper function to hide the keyboard
private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// Custom date formatter
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM, d, yyyy"
    return formatter
}