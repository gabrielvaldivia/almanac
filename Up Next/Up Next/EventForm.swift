import SwiftUI

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
    @EnvironmentObject var appData: AppData
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $newEventTitle)
                    .focused($isTitleFocused)
            }
            Section {
                DatePicker(showEndDate ? "Start Date" : "Date", selection: $newEventDate, displayedComponents: .date)
                if showEndDate {
                    DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                }
                Toggle("Multi-Day", isOn: $showEndDate)
                    .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
            }
            Section {
                Menu {
                    ForEach(RepeatOption.allCases, id: \.self) { option in
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
                    ForEach(appData.categories, id: \.name) { category in
                        Text(category.name).tag(category.name as String?)
                    }
                }
                .onAppear {
                    if selectedCategory == nil {
                        selectedCategory = appData.defaultCategory
                    }
                }

                Button(action: {
                    showCategoryManagementView = true
                }) {
                    Text("Manage Categories")
                        .foregroundColor(.blue)
                }
            }
            Section {
                Toggle("Notify me", isOn: $notificationsEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
            }
            if selectedCategory == nil {
                selectedCategory = appData.defaultCategory.isEmpty ? "Work" : appData.defaultCategory
            }
        }
        .onDisappear {
            isTitleFocused = false
        }
    }

    private func getCategoryColor() -> Color {
        if let selectedCategory = selectedCategory,
           let category = appData.categories.first(where: { $0.name == selectedCategory }) {
            return category.color
        }
        return Color.blue
    }
}