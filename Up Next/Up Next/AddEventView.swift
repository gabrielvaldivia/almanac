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

    var initialDraft: NewEventDraft? = nil
    var initialRecurrence: ParsedEventRecurrence? = nil
    var onSave: () -> Void = {}

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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        showAddEventSheet = false
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tint)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveNewEvent()
                        onSave()
                        showAddEventSheet = false
                    }
                    .disabled(eventDetails.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dateOptions.validationMessage != nil || appData.storageError != nil)
                }
            }
        }
        .tint(categoryOptions.selectedColor.color)
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
            let draft = initialDraft ?? NewEventDraft(title: newEventTitle, date: newEventDate,
                                      endDate: showEndDate ? newEventEndDate : nil,
                                      category: selectedCategory, appData: appData,
                                      recurrence: initialRecurrence)
            eventDetails.title = draft.title
            dateOptions = draft.dateOptions
            useCustomRepeatOptions = draft.usesCustomRepeat
            categoryOptions = draft.categoryOptions
            isTitleFocused = newEventTitle.isEmpty
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

    // Quick entry and the full form share event construction and persistence.
    func saveNewEvent() {
        events.append(contentsOf: NewEventDraft.events(
            title: eventDetails.title, dates: dateOptions, category: categoryOptions))
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
