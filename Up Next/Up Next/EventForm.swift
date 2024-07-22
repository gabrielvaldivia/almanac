import SwiftUI
import WidgetKit

struct EventForm: View {
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor
    @Binding var repeatOption: RepeatOption
    @Binding var repeatUntil: Date
    @Binding var repeatUntilOption: RepeatUntilOption
    @Binding var repeatUntilCount: Int
    @Binding var showCategoryManagementView: Bool
    @Binding var showDeleteActionSheet: Bool
    @Binding var selectedEvent: Event?
    @FocusState var isTitleFocused: Bool
    var deleteEvent: () -> Void
    var deleteSeries: () -> Void
    @EnvironmentObject var appData: AppData
    @State private var showingAddCategorySheet = false
    @State private var showCustomStartDatePicker = false
    @State private var showCustomEndDatePicker = false
    @State private var tempEndDate: Date?
    var showDeleteButtons: Bool
    @Binding var showRepeatOptions: Bool
    @Binding var repeatUnit: String
    @Binding var customRepeatCount: Int

    let predefinedColors: [Color] = [
        .primary, .gray, .red, .green, .blue, .orange, .pink, .purple, .indigo, .mint, .teal, .cyan, .brown
    ]

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack {
                    // TITLE
                    VStack {
                        TextField("Title", text: $newEventTitle)
                            .focused($isTitleFocused)
                            .padding(.horizontal)
                            .frame(height: 40) 
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // DATE
                    VStack {
                        HStack(alignment: .center, spacing: 0) {
                            Button(action: {
                                showCustomStartDatePicker = true
                            }) {
                                Text(newEventDate, formatter: dateFormatter)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 6)
                            .sheet(isPresented: $showCustomStartDatePicker) {
                                VStack {
                                    CustomDatePicker(
                                        selectedDate: Binding<Date?>(
                                            get: { newEventDate },
                                            set: { newEventDate = $0 ?? Date() }
                                        ),
                                        showCustomDatePicker: $showCustomStartDatePicker,
                                        minimumDate: nil,
                                        onDateSelected: {
                                            showCustomStartDatePicker = false
                                        }
                                    )
                                    .presentationDetents([.medium])
                                }
                                .frame(maxHeight: .infinity, alignment: .top)
                            }

                            // END DATE
                            if showEndDate {
                                Text(" → ")
                                    .foregroundColor(.primary)
                                    .padding(.trailing, 6)
                                Button(action: {
                                    showCustomEndDatePicker = true
                                }) {
                                    Text(newEventEndDate, formatter: dateFormatter)
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .sheet(isPresented: $showCustomEndDatePicker) {
                                    VStack {
                                        CustomDatePicker(
                                            selectedDate: $tempEndDate,
                                            showCustomDatePicker: $showCustomEndDatePicker,
                                            minimumDate: Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? newEventDate,
                                            onDateSelected: {
                                                if let selectedDate = tempEndDate {
                                                    showEndDate = true
                                                    newEventEndDate = selectedDate
                                                }
                                                showCustomEndDatePicker = false
                                            }
                                        )
                                        Button(action: {
                                                showEndDate = false
                                                newEventEndDate = newEventDate
                                                tempEndDate = nil
                                                showCustomEndDatePicker = false
                                            }) {
                                                Text("Remove End Date")
                                                    .font(.headline)
                                                    .foregroundColor(.red)
                                            }
                                            .padding()
                                        .presentationDetents([.medium])
                                    }
                                    .frame(maxHeight: .infinity, alignment: .top)
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
                                    VStack {
                                        Text("Add End Date")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .padding(.top, 20)
                                        CustomDatePicker(
                                            selectedDate: $tempEndDate,
                                            showCustomDatePicker: $showCustomEndDatePicker,
                                            minimumDate: Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? newEventDate,
                                            onDateSelected: {
                                                if let selectedDate = tempEndDate {
                                                    showEndDate = true
                                                    newEventEndDate = selectedDate
                                                }
                                                showCustomEndDatePicker = false
                                            }
                                        )
                                        // Button(action: {
                                        //         showEndDate = false
                                        //         newEventEndDate = newEventDate
                                        //         tempEndDate = nil
                                        //         showCustomEndDatePicker = false
                                        //     }) {
                                        //         Text("Cancel")
                                        //             .font(.headline)
                                        //             .foregroundColor(.red)
                                        //     }
                                        //     .padding()
                                        .presentationDetents([.medium])
                                    }
                                    .frame(maxHeight: .infinity, alignment: .top)
                                }
                            }

                            // Repeat Button
                            if !showRepeatOptions {
                                Menu {
                                    ForEach(RepeatOption.allCases.filter { option in
                                        if option == .never {
                                            return false
                                        }
                                        if option == .daily && showEndDate {
                                            return false
                                        }
                                        if option == .weekly && showEndDate && Calendar.current.dateComponents([.day], from: newEventDate, to: newEventEndDate).day! > 6 {
                                            return false
                                        }
                                        return true
                                    }, id: \.self) { option in
                                        Button(action: {
                                            repeatOption = option
                                            showRepeatOptions = option != .never
                                        }) {
                                            Text(option.rawValue)
                                                .foregroundColor(option == repeatOption ? .gray : .primary)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "repeat")
                                        .foregroundColor(.primary)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .padding(.trailing, 6)
                            } else {
                                Button(action: {
                                    repeatOption = .never
                                    showRepeatOptions = false
                                }) {
                                    Image(systemName: "repeat")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(getCategoryColor())
                                        .cornerRadius(8)
                                }
                                .padding(.trailing, 6)
                            }
                        }
                        .padding(.vertical, 6)

                        // REPEAT
                        if showRepeatOptions {
                            VStack {
                                // REPEAT OPTIONS
                                HStack {
                                    Text("Repeat")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Menu {
                                        ForEach(RepeatOption.allCases.filter { option in
                                            if option == .never {
                                                return false
                                            }
                                            if option == .daily && showEndDate {
                                                return false
                                            }
                                            if option == .weekly && showEndDate && Calendar.current.dateComponents([.day], from: newEventDate, to: newEventEndDate).day! > 6 {
                                                return false
                                            }
                                            return true
                                        }, id: \.self) { option in
                                            Button(action: {
                                                repeatOption = option
                                            }) {
                                                Text(option.rawValue)
                                                    .foregroundColor(option == repeatOption ? .gray : .primary)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(repeatOption.rawValue)
                                                .foregroundColor(.gray)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)

                                Divider()
                                    .padding(.leading)

                                // Custom Repeat Option
                                if repeatOption == .custom {
                                    HStack {
                                        Text("Every")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        TextField("", value: $customRepeatCount, formatter: NumberFormatter())
                                            .keyboardType(.numberPad)
                                            .frame(width: 40)
                                            .multilineTextAlignment(.center)
                                            .onChange(of: customRepeatCount) {
                                                if customRepeatCount < 1 {
                                                    customRepeatCount = 1
                                                }
                                            }
                                        Menu {
                                            ForEach(["Days", "Weeks", "Months", "Years"], id: \.self) { unit in
                                                Button(action: {
                                                    repeatUnit = unit
                                                }) {
                                                    Text(unit)
                                                        .foregroundColor(unit == repeatUnit ? .gray : .primary)
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(repeatUnit)
                                                    .foregroundColor(.gray)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)

                                    Divider()
                                    .padding(.leading)
                                }

                                // END REPEAT
                                if repeatOption != .never {
                                    HStack {
                                        Text("End Repeat")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Menu {
                                            Button(action: {
                                                repeatUntilOption = .indefinitely
                                            }) {
                                                Text("Never")
                                                    .foregroundColor(repeatUntilOption == .indefinitely ? .gray : .primary)
                                            }
                                            Button(action: {
                                                repeatUntilOption = .after
                                            }) {
                                                Text("After")
                                                    .foregroundColor(repeatUntilOption == .after ? .gray : .primary)
                                            }
                                            Button(action: {
                                                repeatUntilOption = .onDate
                                            }) {
                                                Text("On")
                                                    .foregroundColor(repeatUntilOption == .onDate ? .gray : .primary)
                                            }
                                        } label: {
                                            HStack {
                                                Text(repeatUntilOption.rawValue)
                                                    .foregroundColor(.gray)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                    .padding(.bottom, repeatUntilOption == .indefinitely ? 12 : 6)
                                    
                                    // AFTER
                                    if repeatUntilOption == .after {
                                        Divider()
                                        .padding(.leading)

                                        HStack {
                                            TextField("", value: $repeatUntilCount, formatter: NumberFormatter())
                                                .keyboardType(.numberPad)
                                                .frame(width: 24)
                                                .multilineTextAlignment(.center)
                                                .onChange(of: repeatUntilCount) {
                                                    if repeatUntilCount < 1 {
                                                        repeatUntilCount = 1
                                                    }
                                                }
                                            Stepper(value: $repeatUntilCount, in: 1...100) {
                                                Text(" \(repeatUntilCount == 1 ? "time" : "times")")
                                            }
                                        }
                                        .padding(.leading)
                                        .padding(.trailing, 6)
                                        .padding(.bottom, 6)
                                    
                                    // ON DATE
                                    } else if repeatUntilOption == .onDate {
                                        Divider()
                                        .padding(.leading)

                                        DatePicker("Date", selection: $repeatUntil, displayedComponents: .date)
                                            .padding(.leading)
                                            .padding(.trailing, 6)
                                            .padding(.bottom, 6)
                                    }
                                }
                            }
                        }
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    

                    // CATEGORY AND COLOR
                    VStack {
                        HStack {
                            Text("Category")
                            Spacer()
                            Menu {
                                Button(action: {
                                    selectedCategory = nil
                                }) {
                                    Text("None").foregroundColor(.gray)
                                }
                                ForEach(appData.categories, id: \.name) { category in
                                    Button(action: {
                                        selectedCategory = category.name
                                        selectedColor = CodableColor(color: category.color)
                                    }) {
                                        Text(category.name).foregroundColor(.gray)
                                    }
                                }
                                Button(action: {
                                    showingAddCategorySheet = true
                                    selectedCategory = nil // Reset the selection
                                }) {
                                    HStack {
                                        Text("Add Category")
                                        Image(systemName: "plus.circle.fill")
                                    }.foregroundColor(.gray)
                                }
                            } label: {
                                HStack {
                                    Text(selectedCategory ?? "None")
                                        .foregroundColor(.gray)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.top, 10)
                        .padding(.leading)
                        .padding(.trailing)

                        .onAppear {
                            if selectedCategory == nil {
                                selectedCategory = appData.defaultCategory.isEmpty ? nil : appData.defaultCategory
                            }
                        }
                        .sheet(isPresented: $showingAddCategorySheet) {
                            NavigationView {
                                AddCategoryView(showingAddCategorySheet: $showingAddCategorySheet) { newCategory in
                                    selectedCategory = newCategory.name
                                    selectedColor = CodableColor(color: newCategory.color)
                                }
                                .environmentObject(appData)
                            }
                            .presentationDetents([.medium, .large], selection: .constant(.medium))
                        }

                        Divider()
                            .padding(.leading)

                        HStack {
                            Text("Color")
                            Spacer()
                            Menu {
                                ForEach(predefinedColors, id: \.self) { color in
                                    Button(action: {
                                        selectedColor = CodableColor(color: color)
                                    }) {
                                        HStack {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 20, height: 20)
                                            Text(color.description.capitalized)
                                        }
                                    }
                                }
                            } label: {
                                Circle()
                                    .fill(selectedColor.color)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding(.bottom, 6)
                        .padding(.leading)
                        .padding(.trailing, 6)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // DELETE EVENT
                    if showDeleteButtons {
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
                                    // .padding(.leading)
                                    
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
                        .padding(.horizontal)
                        // .padding(.vertical, 8)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top) 
            }
            .onAppear {
                if selectedCategory == nil {
                    selectedCategory = appData.defaultCategory.isEmpty ? nil : appData.defaultCategory
                    selectedColor = CodableColor(color: .blue) // Set default color to blue
                } else if let category = appData.categories.first(where: { $0.name == selectedCategory }) {
                    selectedColor = CodableColor(color: category.color)
                }
            }
            .onDisappear {
                isTitleFocused = false
                tempEndDate = nil
                showCustomEndDatePicker = false
                showCustomStartDatePicker = false
            }
        }
    }

    private func getCategoryColor() -> Color {
        return selectedColor.color
    }
}

struct CustomDatePicker: View {
    @Binding var selectedDate: Date?
    @Binding var showCustomDatePicker: Bool
    var minimumDate: Date?
    var onDateSelected: () -> Void
    var onRemoveEndDate: (() -> Void)?

    var body: some View {
        VStack {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { selectedDate ?? Date() },
                    set: { selectedDate = $0 }
                ),
                in: dateRange(),
                displayedComponents: .date
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .onChange(of: selectedDate) { _, _ in
                onDateSelected()
            }
            if let onRemoveEndDate = onRemoveEndDate {
                Button(action: {
                    onRemoveEndDate()
                }) {
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