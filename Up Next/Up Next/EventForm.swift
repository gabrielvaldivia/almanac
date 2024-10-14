import SwiftUI
import WidgetKit

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
    @State private var predefinedColors: [Color] = []

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 16) {
                    TitleSection(newEventTitle: $eventDetails.title, isTitleFocused: _isTitleFocused)
                    DateSection(dateOptions: $dateOptions, showCustomStartDatePicker: $showCustomStartDatePicker, showCustomEndDatePicker: $showCustomEndDatePicker, tempEndDate: $tempEndDate, categoryOptions: $categoryOptions)
                    CategoryAndColorSection(categoryOptions: $categoryOptions, showingAddCategorySheet: $showingAddCategorySheet, showColorPickerSheet: $showColorPickerSheet, appData: appData)
                    if viewState.showDeleteButtons {
                        DeleteSection(selectedEvent: eventDetails.selectedEvent, showDeleteActionSheet: $viewState.showDeleteActionSheet, deleteEvent: deleteEvent, deleteSeries: deleteSeries)
                    }
                }
                .padding()
            }
        }
        .onAppear(perform: setupInitialState)
        .onDisappear(perform: cleanupState)
    }
    
    private func setupInitialState() {
        if categoryOptions.selectedCategory == nil {
            categoryOptions.selectedCategory = appData.defaultCategory.isEmpty ? nil : appData.defaultCategory
            categoryOptions.selectedColor = CodableColor(color: .blue)
        } else if let category = appData.categories.first(where: { $0.name == categoryOptions.selectedCategory }) {
            categoryOptions.selectedColor = CodableColor(color: category.color)
        }
        predefinedColors = CustomColorPickerSheet.predefinedColors
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
                .frame(height: 40)
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
    @Binding var categoryOptions: CategoryOptions
    
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 0) {
                Button(action: { showCustomStartDatePicker = true }) {
                    Text(dateOptions.date, formatter: dateFormatter)
                        .foregroundColor(.primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 6)
                .sheet(isPresented: $showCustomStartDatePicker) {
                    CustomDatePicker(selectedDate: $dateOptions.date, showCustomDatePicker: $showCustomStartDatePicker, minimumDate: nil, onDateSelected: {}, onRemoveEndDate: nil, isEndDatePicker: false, showEndDate: dateOptions.showEndDate)
                        .presentationDetents([.medium])
                }

                if dateOptions.showEndDate {
                    Text(" → ")
                        .foregroundColor(.primary)
                        .padding(.trailing, 6)
                    Button(action: {
                        tempEndDate = dateOptions.endDate
                        showCustomEndDatePicker = true
                    }) {
                        Text(dateOptions.endDate, formatter: dateFormatter)
                            .foregroundColor(.primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .sheet(isPresented: $showCustomEndDatePicker) {
                        CustomDatePicker(selectedDate: Binding(
                            get: { self.tempEndDate ?? Date() },
                            set: { self.tempEndDate = $0 }
                        ), showCustomDatePicker: $showCustomEndDatePicker, minimumDate: Calendar.current.date(byAdding: .day, value: 1, to: dateOptions.date) ?? dateOptions.date, onDateSelected: {
                            if let tempEndDate = tempEndDate {
                                dateOptions.endDate = tempEndDate
                                dateOptions.showEndDate = true
                            }
                        }, onRemoveEndDate: {
                            dateOptions.showEndDate = false
                            dateOptions.endDate = dateOptions.date
                            tempEndDate = nil
                            showCustomEndDatePicker = false
                        }, isEndDatePicker: true, showEndDate: dateOptions.showEndDate)
                        .presentationDetents([.medium])
                    }
                    Spacer()
                } else {
                    Spacer()
                    Button(action: {
                        tempEndDate = nil
                        showCustomEndDatePicker = true
                    }) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.filled.curvepath")
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 6)
                    .sheet(isPresented: $showCustomEndDatePicker) {
                        CustomDatePicker(selectedDate: Binding(
                            get: { self.tempEndDate ?? Date() },
                            set: { self.tempEndDate = $0 }
                        ), showCustomDatePicker: $showCustomEndDatePicker, minimumDate: Calendar.current.date(byAdding: .day, value: 1, to: dateOptions.date) ?? dateOptions.date, onDateSelected: {
                            if let tempEndDate = tempEndDate {
                                dateOptions.endDate = tempEndDate
                                dateOptions.showEndDate = true
                            }
                        }, onRemoveEndDate: {
                            dateOptions.showEndDate = false
                            dateOptions.endDate = dateOptions.date
                            tempEndDate = nil
                            showCustomEndDatePicker = false
                        }, isEndDatePicker: true, showEndDate: dateOptions.showEndDate)
                        .presentationDetents([.medium])
                    }
                }

                // Repeat Button
                Button(action: {
                    if dateOptions.showRepeatOptions {
                        dateOptions.repeatOption = .never
                        dateOptions.showRepeatOptions = false
                    }
                }) {
                    Image(systemName: "repeat")
                        .foregroundColor(dateOptions.repeatOption != .never ? .white : .gray)
                        .padding(8)
                        .background(
                            dateOptions.repeatOption != .never
                            ? categoryOptions.selectedColor.color
                            : Color.gray.opacity(0.2)
                        )
                        .cornerRadius(8)
                }
                .overlay(
                    Group {
                        if !dateOptions.showRepeatOptions {
                            Menu {
                                ForEach(RepeatOption.allCases, id: \.self) { option in
                                    Button(action: {
                                        dateOptions.repeatOption = option
                                        dateOptions.showRepeatOptions = option != .never
                                    }) {
                                        Text(option.rawValue)
                                    }
                                }
                            } label: {
                                Color.clear
                                    .frame(width: 40, height: 40)
                            }
                        }
                    }
                )
                .padding(.trailing, 6)
            }
            .padding(.vertical, 6)

            if dateOptions.showRepeatOptions {
                RepeatOptions(
                    repeatOption: $dateOptions.repeatOption,
                    showRepeatOptions: $dateOptions.showRepeatOptions,
                    customRepeatCount: $dateOptions.customRepeatCount,
                    repeatUnit: $dateOptions.repeatUnit,
                    repeatUntilOption: $dateOptions.repeatUntilOption,
                    repeatUntilCount: $dateOptions.repeatUntilCount,
                    repeatUntil: $dateOptions.repeatUntil
                )
                // .padding(.horizontal)
            }
        }
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
        VStack {
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
                        categoryOptions.selectedCategory = nil
                    }) {
                        HStack {
                            Text("Add Category")
                            Image(systemName: "plus.circle.fill")
                        }.foregroundColor(.gray)
                    }
                } label: {
                    HStack {
                        Text(categoryOptions.selectedCategory ?? "None")
                            .foregroundColor(.gray)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.horizontal)

            Divider()
                .padding(.leading)

            HStack {
                Text("Color")
                Spacer()
                Button(action: { showColorPickerSheet = true }) {
                    Circle()
                        .fill(categoryOptions.selectedColor.color)
                        .frame(width: 24, height: 24)
                        .padding(.trailing, 6)
                }
            }
            .padding(.bottom, 6)
            .padding(.horizontal)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingAddCategorySheet) {
            CategoryForm(
                showingSheet: $showingAddCategorySheet,
                onSave: { newCategory in
                    categoryOptions.selectedCategory = newCategory.name
                    categoryOptions.selectedColor = CodableColor(color: newCategory.color)
                    appData.categories.append((
                        name: newCategory.name,
                        color: newCategory.color,
                        repeatOption: newCategory.repeatOption,
                        customRepeatCount: newCategory.customRepeatCount,
                        repeatUnit: newCategory.repeatUnit,
                        repeatUntilOption: newCategory.repeatUntilOption,
                        repeatUntilCount: newCategory.repeatUntilCount,
                        repeatUntil: newCategory.repeatUntil
                    ))
                    appData.saveCategories()
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
                if event.repeatOption == .never {
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

struct CustomDatePicker: View {
    @Binding var selectedDate: Date
    @Binding var showCustomDatePicker: Bool
    var minimumDate: Date?
    var onDateSelected: () -> Void
    var onRemoveEndDate: (() -> Void)?
    var isEndDatePicker: Bool
    var showEndDate: Bool

    @State private var tempDate: Date

    init(selectedDate: Binding<Date>, showCustomDatePicker: Binding<Bool>, minimumDate: Date?, onDateSelected: @escaping () -> Void, onRemoveEndDate: (() -> Void)?, isEndDatePicker: Bool, showEndDate: Bool) {
        self._selectedDate = selectedDate
        self._showCustomDatePicker = showCustomDatePicker
        self.minimumDate = minimumDate
        self.onDateSelected = onDateSelected
        self.onRemoveEndDate = onRemoveEndDate
        self.isEndDatePicker = isEndDatePicker
        self.showEndDate = showEndDate
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        VStack {
            if isEndDatePicker && !showEndDate {
                Text("Add End Date")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 20)
            }
            
            DatePicker(
                "Date",
                selection: $tempDate,
                in: dateRange(),
                displayedComponents: [.date]
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .onChange(of: tempDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, equalTo: newValue, toGranularity: .month) {
                    // Month or year changed, update tempDate but don't dismiss
                    tempDate = newValue
                } else if !Calendar.current.isDate(oldValue, equalTo: newValue, toGranularity: .day) {
                    // Day changed, update selectedDate, call onDateSelected, and dismiss
                    selectedDate = newValue
                    onDateSelected()
                    showCustomDatePicker = false
                }
            }
            
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
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()