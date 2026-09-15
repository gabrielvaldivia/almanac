import SwiftUI

struct EventForm: View {
    @EnvironmentObject var appData: AppData
    @FocusState var isTitleFocused: Bool

    @Binding var eventDetails: EventDetails
    @Binding var dateOptions: DateOptions
    @Binding var categoryOptions: CategoryOptions
    @Binding var viewState: ViewState

    var deleteEvent: () -> Void
    var deleteSeries: () -> Void

    @State private var showingAddCategorySheet = false
    @State private var showCustomStartDatePicker = false
    @State private var showCustomEndDatePicker = false
    @State private var tempEndDate: Date?
    @State private var showColorPickerSheet = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 16) {
                    TitleSection(
                        newEventTitle: $eventDetails.title, isTitleFocused: _isTitleFocused)
                    DateSection(
                        dateOptions: $dateOptions,
                        showCustomStartDatePicker: $showCustomStartDatePicker,
                        showCustomEndDatePicker: $showCustomEndDatePicker,
                        tempEndDate: $tempEndDate)
                    RepeatSection(dateOptions: $dateOptions)
                    if let message = dateOptions.validationMessage {
                        Text(message).font(.footnote).foregroundStyle(.red)
                    }
                    CategoryAndColorSection(
                        categoryOptions: $categoryOptions,
                        showingAddCategorySheet: $showingAddCategorySheet,
                        showColorPickerSheet: $showColorPickerSheet, appData: appData)
                    if viewState.showDeleteButtons {
                        DeleteSection(
                            selectedEvent: eventDetails.selectedEvent,
                            showDeleteActionSheet: $viewState.showDeleteActionSheet,
                            deleteEvent: deleteEvent, deleteSeries: deleteSeries)
                    }
                }
                .padding()
            }
        }
        .onDisappear(perform: cleanupState)
    }

    private func cleanupState() {
        isTitleFocused = false
        tempEndDate = nil
        showCustomEndDatePicker = false
        showCustomStartDatePicker = false
    }
}

struct TitleSection: View {
    @Binding var newEventTitle: String
    @FocusState var isTitleFocused: Bool

    var body: some View {
        VStack {
            TextField("Title", text: $newEventTitle)
                .focused($isTitleFocused)
                .padding(.horizontal)
                .frame(minHeight: 44)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct DateSection: View {
    @Binding var dateOptions: DateOptions
    @Binding var showCustomStartDatePicker: Bool
    @Binding var showCustomEndDatePicker: Bool
    @Binding var tempEndDate: Date?

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { showCustomStartDatePicker = true }) {
                dateRow("Start date", value: dateFormatter.string(from: dateOptions.date))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start date")
            .accessibilityValue(dateFormatter.string(from: dateOptions.date))

            Divider()
                .padding(.leading)

            Button(action: {
                tempEndDate = dateOptions.showEndDate ? dateOptions.endDate : dateOptions.date
                showCustomEndDatePicker = true
            }) {
                dateRow("End date", value: endDateValue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End date")
            .accessibilityValue(endDateValue)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showCustomStartDatePicker) {
            CustomDatePicker(
                selectedDate: $dateOptions.date,
                showCustomDatePicker: $showCustomStartDatePicker,
                minimumDate: nil,
                onDateSelected: {
                    dateOptions.endDate = max(dateOptions.date, dateOptions.endDate)
                },
                onRemoveEndDate: nil,
                isEndDatePicker: false,
                showEndDate: dateOptions.showEndDate
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCustomEndDatePicker) {
            CustomDatePicker(
                selectedDate: Binding(
                    get: { tempEndDate ?? dateOptions.date },
                    set: { tempEndDate = $0 }
                ),
                showCustomDatePicker: $showCustomEndDatePicker,
                minimumDate: dateOptions.date,
                onDateSelected: {
                    if let tempEndDate = tempEndDate {
                        dateOptions.endDate = tempEndDate
                        dateOptions.showEndDate = true
                    }
                },
                onRemoveEndDate: {
                    dateOptions.showEndDate = false
                    dateOptions.endDate = dateOptions.date
                    tempEndDate = nil
                    showCustomEndDatePicker = false
                },
                isEndDatePicker: true,
                showEndDate: dateOptions.showEndDate
            )
            .presentationDetents([.medium])
        }
    }

    private var endDateValue: String {
        dateOptions.showEndDate ? dateFormatter.string(from: dateOptions.endDate) : "None"
    }

    private func dateRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

struct RepeatSection: View {
    @Binding var dateOptions: DateOptions

    var body: some View {
        RepeatOptions(
            repeatOption: $dateOptions.repeatOption,
            showRepeatOptions: $dateOptions.showRepeatOptions,
            customRepeatCount: $dateOptions.customRepeatCount,
            repeatUnit: $dateOptions.repeatUnit,
            repeatUntilOption: $dateOptions.repeatUntilOption,
            repeatUntilCount: $dateOptions.repeatUntilCount,
            repeatUntil: $dateOptions.repeatUntil
        )
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

}

struct CategoryAndColorSection: View {
    @Binding var categoryOptions: CategoryOptions
    @Binding var showingAddCategorySheet: Bool
    @Binding var showColorPickerSheet: Bool
    @ObservedObject var appData: AppData

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Category")
                Spacer()
                Menu {
                    Button(action: { categoryOptions.selectedCategory = nil }) {
                        Text("None").foregroundColor(.gray)
                    }
                    ForEach(appData.categories, id: \.name) { category in
                        Button(action: {
                            categoryOptions.selectedCategory = category.name
                            categoryOptions.selectedColor = CodableColor(color: category.color)
                        }) {
                            Text(category.name).foregroundColor(.gray)
                        }
                    }
                    Button(action: {
                        showingAddCategorySheet = true
                    }) {
                        HStack {
                            Text("Add Category")
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }.foregroundColor(.gray)
                    }
                } label: {
                    HStack {
                        Text(categoryOptions.selectedCategory ?? "None")
                            .foregroundColor(.gray)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(minHeight: 44)

            Divider()
                .padding(.leading)

            ColorSelectionRow(color: categoryOptions.selectedColor.color) {
                showColorPickerSheet = true
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingAddCategorySheet) {
            CategoryForm(
                showingSheet: $showingAddCategorySheet,
                onSave: { newCategory in
                    categoryOptions.selectedCategory = newCategory.name
                    categoryOptions.selectedColor = CodableColor(color: newCategory.color)
                    appData.categories.append(newCategory)
                }
            )
            .environmentObject(appData)
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showColorPickerSheet) {
            CustomColorPickerSheet(
                selectedColor: $categoryOptions.selectedColor,
                showColorPickerSheet: $showColorPickerSheet
            )
            .presentationDetents([.fraction(0.4)])
        }
    }
}

struct DeleteSection: View {
    var selectedEvent: Event?
    @Binding var showDeleteActionSheet: Bool
    var deleteEvent: () -> Void
    var deleteSeries: () -> Void

    var body: some View {
        VStack {
            if let event = selectedEvent {
                if event.seriesID == nil {
                    Button("Delete Event") {
                        showDeleteActionSheet = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    Button("Delete Event") {
                        deleteEvent()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                    Divider()

                    Button("Delete Series") {
                        deleteSeries()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// DATE PICKER
struct CustomDatePicker: View {
    @Binding var selectedDate: Date
    @Binding var showCustomDatePicker: Bool
    var minimumDate: Date?
    var onDateSelected: () -> Void
    var onRemoveEndDate: (() -> Void)?
    var isEndDatePicker: Bool
    var showEndDate: Bool

    @State private var tempDate: Date

    init(
        selectedDate: Binding<Date>, showCustomDatePicker: Binding<Bool>, minimumDate: Date?,
        onDateSelected: @escaping () -> Void, onRemoveEndDate: (() -> Void)?, isEndDatePicker: Bool,
        showEndDate: Bool
    ) {
        self._selectedDate = selectedDate
        self._showCustomDatePicker = showCustomDatePicker
        self.minimumDate = minimumDate
        self.onDateSelected = onDateSelected
        self.onRemoveEndDate = onRemoveEndDate
        self.isEndDatePicker = isEndDatePicker
        self.showEndDate = showEndDate
        self._tempDate = State(initialValue: max(selectedDate.wrappedValue, minimumDate ?? Date.distantPast))
    }

    var body: some View {
        VStack {
            if isEndDatePicker && !showEndDate {
                HStack {
                    Text("Add End Date")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Done", action: confirmSelection)
                        .accessibilityIdentifier("confirmInitialEndDate")
                }
                .padding(.top, 20)
            }

            DatePicker(
                "Date",
                selection: $tempDate,
                in: dateRange(),
                displayedComponents: [.date]
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .onChange(of: tempDate) { _, _ in confirmSelection() }

            if isEndDatePicker && showEndDate, let onRemoveEndDate = onRemoveEndDate {
                Button(action: onRemoveEndDate) {
                    Text("Remove End Date")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .padding()
            }
        }
        .padding(.horizontal)
    }

    private func dateRange() -> ClosedRange<Date> {
        if let minimumDate = minimumDate {
            return minimumDate...Date.distantFuture
        } else {
            return Date.distantPast...Date.distantFuture
        }
    }

    private func confirmSelection() {
        selectedDate = tempDate
        onDateSelected()
        showCustomDatePicker = false
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()
