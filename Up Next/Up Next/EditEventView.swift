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

// Enum for delete options
enum DeleteOption {
    case thisEvent
    case allEvents
}

// Struct for event details
public struct EventDetails {
    var title: String
    var selectedEvent: Event?
}

// Struct for date options
public struct DateOptions {
    var date: Date
    var endDate: Date
    var showEndDate: Bool
    var repeatOption: RepeatOption
    var repeatUntil: Date
    var repeatUntilOption: RepeatUntilOption
    var repeatUntilCount: Int
    var showRepeatOptions: Bool
    var repeatUnit: String
    var customRepeatCount: Int

    var validationMessage: String? {
        let calendar = Calendar.current
        if showEndDate && calendar.startOfDay(for: endDate) < calendar.startOfDay(for: date) { return "End date must be on or after the start date." }
        if repeatOption == .custom && !(1...1000).contains(customRepeatCount) { return "Repeat interval must be between 1 and 1,000." }
        if repeatOption != .never && repeatUntilOption == .after && !(1...10000).contains(repeatUntilCount) { return "Repeat count must be between 1 and 10,000." }
        if repeatOption != .never && repeatUntilOption == .onDate && calendar.startOfDay(for: repeatUntil) < calendar.startOfDay(for: date) { return "Repeat end date must be on or after the start date." }
        return nil
    }
}

// Struct for category options
public struct CategoryOptions {
    var selectedCategory: String?
    var selectedColor: CodableColor
}

// Struct for view state
public struct ViewState {
    var showCategoryManagementView: Bool
    var showDeleteActionSheet: Bool
    var showDeleteButtons: Bool
}

// Main view for editing an event
struct EditEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var showEditSheet: Bool

    @State private var eventDetails: EventDetails
    @State private var dateOptions: DateOptions
    @State private var categoryOptions: CategoryOptions
    @State private var viewState: ViewState
    @State private var useCustomRepeatOptions: Bool = false

    @State private var showDeleteSeriesAlert = false
    @State private var deleteOption: DeleteOption = .thisEvent
    @State private var showUpdateActionSheet = false
    @State private var shouldDismissEditSheet = false

    // Function to save the event
    let saveEvents: () -> Void

    // Environment object to access shared app data
    @EnvironmentObject var appData: AppData

    init(
        events: Binding<[Event]>, selectedEvent: Binding<Event?>, showEditSheet: Binding<Bool>,
        saveEvents: @escaping () -> Void
    ) {
        self._events = events
        self._selectedEvent = selectedEvent
        self._showEditSheet = showEditSheet
        self.saveEvents = saveEvents

        let event =
            selectedEvent.wrappedValue
            ?? Event(title: "", date: Date(), color: CodableColor(color: .blue))
        self._eventDetails = State(
            initialValue: EventDetails(title: event.title, selectedEvent: event))
        self._dateOptions = State(
            initialValue: DateOptions(
                date: event.date,
                endDate: event.endDate ?? event.date,
                showEndDate: event.endDate != nil,
                repeatOption: event.repeatOption,
                repeatUntil: event.repeatUntil ?? Date(),
                repeatUntilOption: event.recurrence?.end ?? (event.repeatUntil == nil ? .indefinitely : .onDate),
                repeatUntilCount: event.repeatUntilCount ?? 1,
                showRepeatOptions: event.repeatOption != .never,
                repeatUnit: event.repeatUnit ?? "Days",
                customRepeatCount: event.customRepeatCount ?? 1
            ))
        self._categoryOptions = State(
            initialValue: CategoryOptions(
                selectedCategory: event.category,
                selectedColor: event.color
            ))
        self._viewState = State(
            initialValue: ViewState(
                showCategoryManagementView: false,
                showDeleteActionSheet: false,
                showDeleteButtons: true
            ))
    }

    var body: some View {
        NavigationView {
            EventForm(
                eventDetails: $eventDetails,
                dateOptions: $dateOptions,
                categoryOptions: $categoryOptions,
                viewState: $viewState,
                useCustomRepeatOptions: $useCustomRepeatOptions,
                deleteEvent: deleteEvent,
                deleteSeries: { showDeleteSeriesAlert = true }
            )
            .environmentObject(appData)
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar with cancel and save buttons
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showEditSheet = false
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .accessibilityLabel("Cancel")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if eventDetails.selectedEvent?.seriesID == nil {
                            applyChanges(to: .thisEvent)
                            showEditSheet = false
                        } else {
                            showUpdateActionSheet = true
                        }
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(categoryOptions.selectedColor.color)
                                    .frame(width: 60, height: 32)
                                Text("Save")
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
                    .disabled(eventDetails.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dateOptions.validationMessage != nil || appData.storageError != nil)
                }
            }
            .alert(isPresented: $viewState.showDeleteActionSheet) {
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
                if eventDetails.selectedEvent?.seriesID != nil {
                    return ActionSheet(
                        title: Text("Update Event"),
                        message: Text(
                            "Do you want to apply the changes to this event only or all events in the series?"
                        ),
                        buttons: [
                            .default(Text("This Event Only")) {
                                applyChanges(to: .thisEvent)
                                shouldDismissEditSheet = true
                            },
                            .default(Text("All Events in Series")) {
                                applyChanges(to: .allEvents)
                                shouldDismissEditSheet = true
                            },
                            .cancel(),
                        ]
                    )
                } else {
                    applyChanges(to: .thisEvent)
                    shouldDismissEditSheet = true
                    return ActionSheet(title: Text(""), message: Text(""), buttons: [])
                }
            }
        }
        .onAppear(perform: setupInitialState)
        .alertController(
            isPresented: $showDeleteSeriesAlert, title: "Delete Series",
            message: "Are you sure you want to delete all events in this series?",
            confirmAction: deleteSeries
        )
        .onChange(of: shouldDismissEditSheet) { oldValue, newValue in
            if newValue {
                showEditSheet = false
                shouldDismissEditSheet = false
            }
        }

    }

    // Function to delete an event
    private func deleteEvent() {
        guard let event = selectedEvent else { return }
        appData.deleteEvent(event)
        showEditSheet = false
    }

    // Function to delete a series of events
    func deleteSeries() {
        guard let event = eventDetails.selectedEvent else { return }
        events = EventSeries.removing(event, from: events)
        saveEvents()
        showEditSheet = false
    }

    // Function to delete a single event
    func deleteSingleEvent() {
        guard let event = eventDetails.selectedEvent else { return }
        appData.deleteEvent(event)
    }

    // Function to get the color of the selected category
    func getCategoryColor() -> Color {
        return categoryOptions.selectedColor.color
    }

    // Custom date formatter
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM, d, yyyy"
        return formatter
    }

    // Function to apply changes to an event or series of events
    func applyChanges(to option: DeleteOption) {
        guard let event = eventDetails.selectedEvent else { return }
        var updated = event
        updated.title = eventDetails.title
        updated.date = dateOptions.date
        updated.endDate = dateOptions.showEndDate ? dateOptions.endDate : nil
        updated.category = categoryOptions.selectedCategory
        updated.color = categoryOptions.selectedColor
        updated.repeatOption = dateOptions.repeatOption
        updated.customRepeatCount = dateOptions.customRepeatCount
        updated.repeatUnit = dateOptions.repeatUnit
        updated.repeatUntil = dateOptions.repeatUntilOption == .onDate ? dateOptions.repeatUntil : nil
        updated.repeatUntilCount = dateOptions.repeatUntilCount
        updated.recurrence = RecurrenceRule(event: updated, end: dateOptions.repeatUntilOption)
        switch option {
        case .thisEvent:
            if event.seriesID != nil {
                updated.recurrence = event.recurrence
                updated.isRecurrenceException = true
                if let index = events.firstIndex(where: { $0.id == event.id }) { events[index] = updated }
            } else if updated.repeatOption != .never {
                updated.seriesID = UUID()
                events.removeAll { $0.id == event.id }
                events.append(contentsOf: generateRepeatingEvents(for: updated, repeatUntilOption: dateOptions.repeatUntilOption, showEndDate: dateOptions.showEndDate))
            } else {
                updated.recurrence = nil
                if let index = events.firstIndex(where: { $0.id == event.id }) { events[index] = updated }
            }
        case .allEvents:
            if event.seriesID == nil {
                if let index = events.firstIndex(where: { $0.id == event.id }) { events[index] = updated }
            } else {
                events = EventSeries.updating(event, with: updated, in: events)
            }
        }
        saveEvents()
    }

    private func setupInitialState() {
        if let event = selectedEvent {
            eventDetails.selectedEvent = event
            eventDetails.title = event.title
            dateOptions.date = event.date
            dateOptions.endDate = event.endDate ?? event.date
            dateOptions.showEndDate = event.endDate != nil

            dateOptions.repeatOption = event.repeatOption
            dateOptions.repeatUntil = event.recurrence?.until ?? event.repeatUntil ?? event.date
            dateOptions.repeatUntilOption = event.recurrence?.end ?? (event.repeatUntil == nil ? .indefinitely : .onDate)
            dateOptions.repeatUntilCount = event.recurrence?.count ?? event.repeatUntilCount ?? 1
            dateOptions.showRepeatOptions = event.repeatOption != .never
            dateOptions.repeatUnit = event.repeatUnit ?? "Days"
            dateOptions.customRepeatCount = event.customRepeatCount ?? 1

            categoryOptions.selectedCategory = event.category
            categoryOptions.selectedColor = event.color

            useCustomRepeatOptions = event.repeatOption != .never
        }
    }
}

// Custom view modifier for alert controller
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

// Representable for alert controller
struct AlertControllerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var confirmAction: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()  // A dummy view controller required to present the alert
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, uiViewController.presentedViewController == nil else { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel) { _ in
                isPresented = false
            })
        alert.addAction(
            UIAlertAction(title: "Delete", style: .destructive) { _ in
                confirmAction()
                isPresented = false
            })

        DispatchQueue.main.async {
            uiViewController.present(alert, animated: true, completion: nil)
        }
    }
}

// Extension to add alert controller modifier to any view
extension View {
    func alertController(
        isPresented: Binding<Bool>, title: String, message: String,
        confirmAction: @escaping () -> Void
    ) -> some View {
        self.modifier(
            AlertControllerModifier(
                isPresented: isPresented, title: title, message: message,
                confirmAction: confirmAction))
    }
}
