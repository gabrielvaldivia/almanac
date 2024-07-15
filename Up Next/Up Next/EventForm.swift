import SwiftUI
import WidgetKit

struct EventForm: View {
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor
    @Binding var notificationsEnabled: Bool
    @Binding var repeatOption: RepeatOption
    @Binding var repeatUntil: Date
    @Binding var repeatUntilOption: RepeatUntilOption
    @Binding var repeatCount: Int
    @Binding var showCategoryManagementView: Bool
    @Binding var showDeleteActionSheet: Bool
    @Binding var selectedEvent: Event?
    var deleteEvent: () -> Void
    var deleteSeries: () -> Void
    @EnvironmentObject var appData: AppData
    @FocusState private var isTitleFocused: Bool
    @State private var showingAddCategorySheet = false
    @State private var showCustomStartDatePicker = false
    @State private var showCustomEndDatePicker = false
    @State private var tempEndDate: Date?
    @State private var showRepeatOptions = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground) // Set the background color to match the Form's background
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                
                // TITLE
                VStack {
                    TextField("Title", text: $newEventTitle)
                        .focused($isTitleFocused)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // DATE
                VStack {
                    HStack(alignment: .center, spacing: 0) {
                        Button(action: {
                            print("Start Date Button Tapped")
                            showCustomStartDatePicker = true
                            showCustomEndDatePicker = false // Ensure end date picker is closed
                            print("showCustomStartDatePicker: \(showCustomStartDatePicker), showCustomEndDatePicker: \(showCustomEndDatePicker)")
                        }) {
                            Text(newEventDate, formatter: dateFormatter)
                                .foregroundColor(.primary)
                                .padding(6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 6)

                        // END DATE
                        if showEndDate {
                            Text(" - ")
                                .foregroundColor(.primary)
                                .padding(.horizontal, 4)
                            Button(action: {
                                print("End Date Button Tapped")
                                showCustomEndDatePicker = true
                                showCustomStartDatePicker = false // Ensure start date picker is closed
                                print("showCustomStartDatePicker: \(showCustomStartDatePicker), showCustomEndDatePicker: \(showCustomEndDatePicker)")
                            }) {
                                Text(newEventEndDate, formatter: dateFormatter)
                                    .foregroundColor(.primary)
                                    .padding(6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            Spacer()
                        } else {
                            Spacer()
                            Button(action: {
                                print("Add End Date Button Tapped")
                                tempEndDate = nil
                                showCustomEndDatePicker = true
                                showCustomStartDatePicker = false // Ensure start date picker is closed
                                print("showCustomStartDatePicker: \(showCustomStartDatePicker), showCustomEndDatePicker: \(showCustomEndDatePicker)")
                            }) {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(.primary)
                                    .padding(6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 6)
                        }

                        // Repeat Button
                        if showRepeatOptions {
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
                        } else {
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
                                        showRepeatOptions = (option != .never)
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
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)

                    // REPEAT
                    if showRepeatOptions {
                        VStack {
                            // REPEAT OPTIONS
                            HStack {
                                Text("Repeat")
                                    .foregroundColor(.primary)
                                Spacer()
                                Picker("", selection: $repeatOption) {
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
                                        Text(option.rawValue)
                                            .foregroundColor(option == repeatOption ? .gray : .primary)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: repeatOption) { newValue in
                                    showRepeatOptions = (newValue != .never)
                                }
                                .foregroundColor(.gray)
                            }
                            .padding(.leading)
                            .padding(.vertical, 8)

                            // END REPEAT
                            if repeatOption != .never {
                                HStack {
                                    Text("End Repeat")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Picker("", selection: $repeatUntilOption) {
                                        Text("Never")
                                            .tag(RepeatUntilOption.indefinitely)
                                            .foregroundColor(repeatUntilOption == .indefinitely ? .gray : .primary)
                                        Text("After")
                                            .tag(RepeatUntilOption.after)
                                            .foregroundColor(repeatUntilOption == .after ? .gray : .primary)
                                        Text("On")
                                            .tag(RepeatUntilOption.onDate)
                                            .foregroundColor(repeatUntilOption == .onDate ? .gray : .primary)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .foregroundColor(.gray)
                                }
                                .padding(.leading)
                                .padding(.vertical, 8)

                                // REPEAT COUNT
                                if repeatUntilOption == .after {
                                    HStack {
                                        TextField("", value: $repeatCount, formatter: NumberFormatter())
                                            .keyboardType(.numberPad)
                                            .frame(width: 24)
                                            .multilineTextAlignment(.center)
                                            .onChange(of: repeatCount) {
                                                if repeatCount < 1 {
                                                    repeatCount = 1
                                                }
                                            }
                                        Stepper(value: $repeatCount, in: 1...100) {
                                            Text(" \(repeatCount == 1 ? (repeatOption == .daily ? "day" : repeatOption == .weekly ? "week" : repeatOption == .monthly ? "month" : "year") : (repeatOption == .daily ? "days" : repeatOption == .weekly ? "weeks" : repeatOption == .monthly ? "months" : "years"))")
                                        }
                                    }
                                    .padding(.leading)
                                    .padding(.trailing, 6)
                                    .padding(.bottom, 6)
                                
                                // REPEAT UNTIL ON DATE
                                } else if repeatUntilOption == .onDate {
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
                        Picker("", selection: $selectedCategory) {
                            Text("None").tag(nil as String?) // Show "Select" when no category is selected
                            ForEach(appData.categories, id: \.name) { category in
                                Text(category.name).tag(category.name as String?)
                            }
                            HStack {
                                Text("Add Category")
                                Image(systemName: "plus.circle.fill")
                            }.tag("addCategory" as String?)
                        }
                        .onChange(of: selectedCategory) { oldValue, newValue in
                            if newValue == "addCategory" {
                                showingAddCategorySheet = true
                                selectedCategory = nil // Reset the selection
                            } else if let category = appData.categories.first(where: { $0.name == newValue }) {
                                selectedColor = CodableColor(color: category.color)
                            }
                        }
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
                    }
                    .padding(.top, 6)
                    .padding(.leading)

                    Divider()
                        .padding(.leading)

                    HStack {
                        Text("Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { selectedColor.color },
                            set: { selectedColor = CodableColor(color: $0) }
                        ))
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                    }
                    .padding(.bottom, 6)
                    .padding(.leading)
                    .padding(.trailing, 6)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // NOTIFY ME
                VStack {
                    Toggle("Notify me", isOn: $notificationsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
                        .padding(.vertical, 6)
                        .padding(.leading)
                        .padding(.trailing, 10)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // DELETE EVENT
                Section {
                    if let event = selectedEvent {
                        if event.repeatOption == .never {
                            Button("Delete Event") {
                                showDeleteActionSheet = true
                            }
                            .foregroundColor(.red)
                        } else {
                            Button("Delete Event") {
                                deleteEvent()
                            }
                            .foregroundColor(.red)
                            
                            Button("Delete Series") {
                                deleteSeries()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: .infinity, alignment: .top) 
            if showCustomStartDatePicker {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            print("Dismiss Start Date Picker")
                            showCustomStartDatePicker = false
                        }
                    }
                VStack {
                    Spacer()
                    VStack {
                        CustomDatePicker(
                            selectedDate: Binding<Date?>(
                                get: { newEventDate },
                                set: { newEventDate = $0 ?? Date() }
                            ),
                            showCustomDatePicker: $showCustomStartDatePicker,
                            minimumDate: Date(),
                            onDateSelected: {
                                print("Start Date Selected: \(newEventDate)")
                                showCustomStartDatePicker = false
                            }
                        )
                    }
                    .frame(maxWidth: 350)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .scaleEffect(showCustomStartDatePicker ? 1 : 0.5) // Scale effect
                    .animation(.spring(), value: showCustomStartDatePicker) // Animation
                    Spacer()
                }
            }
            if showCustomEndDatePicker {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            print("Dismiss End Date Picker")
                            showCustomEndDatePicker = false
                            tempEndDate = nil
                        }
                    }
                VStack {
                    Spacer()
                    VStack {
                        CustomDatePicker(
                            selectedDate: $tempEndDate,
                            showCustomDatePicker: $showCustomEndDatePicker,
                            minimumDate: Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? newEventDate,
                            onDateSelected: {
                                if let selectedDate = tempEndDate {
                                    print("End Date Selected: \(selectedDate)")
                                    showEndDate = true
                                    newEventEndDate = selectedDate
                                }
                                showCustomEndDatePicker = false
                            },
                            onRemoveEndDate: {
                                print("Remove End Date")
                                showEndDate = false
                                newEventEndDate = newEventDate
                                tempEndDate = nil
                                showCustomEndDatePicker = false
                            }
                        )
                    }
                    .frame(maxWidth: 350)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 20)
                    .scaleEffect(showCustomEndDatePicker ? 1 : 0.5) // Scale effect
                    .animation(.spring(), value: showCustomEndDatePicker) // Animation
                    Spacer()
                }
            }
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

    private func getCategoryColor() -> Color {
        return selectedColor.color
    }
}

struct CustomDatePicker: View {
    @Binding var selectedDate: Date?
    @Binding var showCustomDatePicker: Bool
    var minimumDate: Date
    var onDateSelected: () -> Void
    var onRemoveEndDate: (() -> Void)?

    var body: some View {
        VStack {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { selectedDate ?? minimumDate },
                    set: { selectedDate = $0 }
                ),
                in: minimumDate...,
                displayedComponents: .date
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .onChange(of: selectedDate) { _, _ in
                onDateSelected()
            }
            if let onRemoveEndDate = onRemoveEndDate {
                Button("Remove End Date") {
                    onRemoveEndDate()
                }
                .foregroundColor(.red)
                .padding()
            }
        }
        .padding(.horizontal)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()