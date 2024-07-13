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
    @State private var showCustomEndDatePicker = false

    var body: some View {
        ZStack {
            Form {
                Section {
                    TextField("Title", text: $newEventTitle)
                        .focused($isTitleFocused)
                }
                Section {
                    HStack {
                        DatePicker("Day", selection: $newEventDate, displayedComponents: .date)
                            .onChange(of: newEventDate) { oldValue, newValue in
                                let minimumEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
                                if newEventEndDate < minimumEndDate {
                                    newEventEndDate = minimumEndDate
                                }
                            }
                        if showEndDate {
                            Text(" - ")
                                .foregroundColor(.primary)
                            Button(action: {
                                showCustomEndDatePicker.toggle()
                            }) {
                                Text("\(newEventEndDate, formatter: dateFormatter)")
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.primary)
                            }
                        } else {
                            Spacer()
                            Button(action: {
                                showEndDate = true
                                newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? newEventDate
                                showCustomEndDatePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                        .foregroundColor(.primary)
                                }
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                Section {
                    Menu {
                        ForEach(RepeatOption.allCases.filter { option in
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
                            Text("Repeat")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(repeatOption.rawValue)
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.gray)
                                .font(.footnote)
                        }
                    }

                    if repeatOption != .never {
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
                                Text("End Repeat")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(repeatUntilOption.rawValue)
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.gray)
                                    .font(.footnote)
                            }
                        }

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
                                    Text(" times")
                                }
                            }
                        } else if repeatUntilOption == .onDate {
                            DatePicker("Date", selection: $repeatUntil, displayedComponents: .date)
                        }
                    }
                }
                Section {
                    Picker("Category", selection: $selectedCategory) {
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
                    
                    ColorPicker("Color", selection: Binding(
                        get: { selectedColor.color },
                        set: { selectedColor = CodableColor(color: $0) }
                    ))
                }
                Section {
                    Toggle("Notify me", isOn: $notificationsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
                }
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
        }
            if showCustomEndDatePicker {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            showCustomEndDatePicker = false
                        }
                    }
                VStack {
                    Spacer()
                    CustomDatePicker(date: $newEventEndDate, showEndDate: $showEndDate, showCustomEndDatePicker: $showCustomEndDatePicker, minimumDate: Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? newEventDate)
                        .frame(width: 300, height: 350)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 20)
                        .transition(.scale)
                        .animation(.easeInOut(duration: 0.3), value: showCustomEndDatePicker)
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
        }
    }

    private func getCategoryColor() -> Color {
        return selectedColor.color
    }
}

struct CustomDatePicker: View {
    @Binding var date: Date
    @Binding var showEndDate: Bool
    @Binding var showCustomEndDatePicker: Bool
    var minimumDate: Date

    var body: some View {
        VStack {
            DatePicker("End Date", selection: $date, in: minimumDate..., displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .onChange(of: date) { _, newValue in
                    withAnimation {
                        showCustomEndDatePicker = false
                    }
                }
            Button("Remove End Date") {
                withAnimation {
                    showEndDate = false
                    showCustomEndDatePicker = false
                }
            }
            .foregroundColor(.red)
            .padding()
        }
        .padding()
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()