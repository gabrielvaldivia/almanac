import SwiftUI

struct CategoryForm: View {
    @Binding var categoryName: String
    @Binding var categoryColor: Color
    @Binding var showColorPickerSheet: Bool
    @Binding var repeatOption: RepeatOption
    @Binding var showRepeatOptions: Bool
    @Binding var customRepeatCount: Int
    @Binding var repeatUnit: String
    @Binding var repeatUntilOption: RepeatUntilOption
    @Binding var repeatUntilCount: Int
    @Binding var repeatUntil: Date
    @FocusState private var isCategoryNameFieldFocused: Bool
    var isEditing: Bool
    var saveAction: () -> Void
    
    var body: some View {
        Form {
            TextField("Category Name", text: $categoryName)
                .focused($isCategoryNameFieldFocused)
            HStack {
                Text("Color")
                Spacer()
                Button(action: {
                    showColorPickerSheet = true
                }) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 24, height: 24)
                }
            }
            
            // REPEAT
            VStack {
                // REPEAT OPTIONS
                HStack {
                    Text("Repeat")
                        .foregroundColor(.primary)
                    Spacer()
                    Menu {
                        ForEach(RepeatOption.allCases.filter { $0 != .never }, id: \.self) { option in
                            Button(action: {
                                repeatOption = option
                                showRepeatOptions = option != .never
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
                .padding(.vertical, 6)

                if showRepeatOptions {
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
                        .padding(.vertical, 6)
                    }

                    // END REPEAT
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
                    .padding(.top, 8)
                    .padding(.bottom, repeatUntilOption == .indefinitely ? 6 : 6)
                    
                    // AFTER
                    if repeatUntilOption == .after {
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
                        .padding(.bottom, 6)
                    
                    // ON DATE
                    } else if repeatUntilOption == .onDate {
                        DatePicker("Date", selection: $repeatUntil, displayedComponents: .date)
                            .padding(.bottom, 6)
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCategoryNameFieldFocused = true
            }
        }
    }
}
