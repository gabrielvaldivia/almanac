//
//  Events.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UserNotifications
import WidgetKit  // Add this import

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
    @Binding var selectedColor: CodableColor  // Use CodableColor to store color

    // Environment object to access shared app data
    @EnvironmentObject var appData: AppData

    // Focus state for managing keyboard focus
    @FocusState private var isTitleFocused: Bool  // Add this line to manage focus state

    // State variables for repeat options
    @State private var repeatOption: RepeatOption = .never  // Changed from .none to .never
    @State private var repeatUntil: Date =
        Calendar.current.date(
            from: DateComponents(
                year: Calendar.current.component(.year, from: Date()), month: 12, day: 31))
        ?? Date()
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely  // New state variable
    @State private var repeatUntilCount: Int = 1  // New state variable for number of repetitions
    @State private var customRepeatCount: Int = 1  // Initialize customRepeatCount to 1
    @State private var repeatUnit: String = "Days"  // Initialize repeatUnit to "Days"

    // State variables for UI management
    @State private var showCategoryManagementView = false  // Add this state variable
    @State private var showDeleteActionSheet = false  // Add this state variable
    @State private var showRepeatOptions = false  // Set this to false by default

    @State private var eventDetails = EventDetails(
        title: "", selectedEvent: Event(title: "", date: Date(), color: CodableColor(color: .blue)))
    @State private var dateOptions = DateOptions(
        date: Date(), endDate: Date(), showEndDate: false, repeatOption: .never,
        repeatUntil: Date(), repeatUntilOption: .indefinitely, repeatUntilCount: 1,
        showRepeatOptions: false, repeatUnit: "Days", customRepeatCount: 1)
    @State private var categoryOptions = CategoryOptions(
        selectedCategory: nil, selectedColor: CodableColor(color: .blue))
    @State private var viewState = ViewState(
        showCategoryManagementView: false, showDeleteActionSheet: false, showDeleteButtons: false)

    @State private var useCustomRepeatOptions: Bool = false
    @State private var hasInitialized = false

    var body: some View {
        NavigationView {
            // Event form view
            EventForm(
                eventDetails: $eventDetails,
                dateOptions: $dateOptions,
                categoryOptions: $categoryOptions,
                viewState: $viewState,
                useCustomRepeatOptions: $useCustomRepeatOptions,
                deleteEvent: {},
                deleteSeries: {}
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
                                    .fill(categoryOptions.selectedColor.color)
                                    .frame(width: 60, height: 32)
                                Text("Add")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(
                                        CustomColorPickerSheet(
                                            selectedColor: $categoryOptions.selectedColor,
                                            showColorPickerSheet: .constant(false)
                                        ).contrastColor)
                            }
                        }
                        .opacity(eventDetails.title.isEmpty ? 0.3 : 1.0)
                    }
                    .disabled(eventDetails.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dateOptions.validationMessage != nil)
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
            guard !hasInitialized else { return }
            hasInitialized = true
            isTitleFocused = true
            eventDetails.title = newEventTitle
            dateOptions.date = newEventDate
            dateOptions.endDate = max(newEventDate, newEventEndDate)
            dateOptions.showEndDate = showEndDate
            categoryOptions.selectedCategory = selectedCategory ?? (appData.defaultCategory.isEmpty ? nil : appData.defaultCategory)
            categoryOptions.selectedColor = selectedColor
            if let category = appData.categories.first(where: { $0.name == categoryOptions.selectedCategory }) {
                categoryOptions.selectedColor = CodableColor(color: category.color)
                dateOptions.repeatOption = category.repeatOption
                dateOptions.showRepeatOptions = category.repeatOption != .never
                dateOptions.customRepeatCount = category.customRepeatCount
                dateOptions.repeatUnit = category.repeatUnit
                dateOptions.repeatUntilOption = category.repeatUntilOption
                dateOptions.repeatUntilCount = category.repeatUntilCount
                dateOptions.repeatUntil = category.repeatUntil
            }
        }
        .onDisappear {
            // Clear focus when view disappears
            isTitleFocused = false
        }
        .onChange(of: categoryOptions.selectedCategory) { oldValue, newValue in
            if let category = appData.categories.first(where: { $0.name == newValue }) {
                if !useCustomRepeatOptions {
                    dateOptions.repeatOption = category.repeatOption
                    dateOptions.showRepeatOptions = category.repeatOption != .never
                    dateOptions.customRepeatCount = category.customRepeatCount
                    dateOptions.repeatUnit = category.repeatUnit
                    dateOptions.repeatUntilOption = category.repeatUntilOption
                    dateOptions.repeatUntilCount = category.repeatUntilCount
                    dateOptions.repeatUntil = category.repeatUntil
                }
                categoryOptions.selectedColor = CodableColor(color: category.color)
            }
        }
    }

    // Function to save the new event
    func saveNewEvent() {
        let repeatUntilDate: Date?
        switch dateOptions.repeatUntilOption {
        case .indefinitely:
            repeatUntilDate = Calendar.current.date(byAdding: .year, value: 1, to: dateOptions.date)
        case .after:
            repeatUntilDate = calculateRepeatUntilDate(
                for: dateOptions.repeatOption,
                from: dateOptions.date,
                count: dateOptions.repeatUntilCount,
                repeatUnit: dateOptions.repeatUnit)
        case .onDate:
            repeatUntilDate = dateOptions.repeatUntil
        }

        let newEvent = Event(
            title: eventDetails.title,
            date: dateOptions.date,
            endDate: dateOptions.showEndDate ? dateOptions.endDate : nil,
            color: categoryOptions.selectedColor,
            category: categoryOptions.selectedCategory,
            repeatOption: dateOptions.repeatOption,
            repeatUntil: repeatUntilDate,
            seriesID: dateOptions.repeatOption != .never ? UUID() : nil,
            customRepeatCount: dateOptions.customRepeatCount,
            repeatUnit: dateOptions.repeatUnit,
            repeatUntilCount: dateOptions.repeatUntilCount,
            useCustomRepeatOptions: true
        )

        if dateOptions.repeatOption != .never {
            let repeatingEvents = generateRepeatingEvents(
                for: newEvent,
                repeatUntilOption: dateOptions.repeatUntilOption,
                showEndDate: dateOptions.showEndDate
            )
            events.append(contentsOf: repeatingEvents)
        } else {
            events.append(newEvent)
        }

        appData.saveEvents()
    }

    // Helper function to get the color of the selected category
    func getCategoryColor() -> Color {
        return selectedColor.color
    }

}

// Helper function to hide the keyboard
private func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// Custom date formatter
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM, d, yyyy"
    return formatter
}
