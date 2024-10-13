//
//  RepeatOptions.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 10/13/24.
//

import Foundation
import SwiftUI

struct RepeatOptions: View {
    @Binding var repeatOption: RepeatOption
    @Binding var showRepeatOptions: Bool
    @Binding var customRepeatCount: Int
    @Binding var repeatUnit: String
    @Binding var repeatUntilOption: RepeatUntilOption
    @Binding var repeatUntilCount: Int
    @Binding var repeatUntil: Date

    // Move the computed property here, outside of body
    private var repeatUntilOptionDisplayText: String {
        switch repeatUntilOption {
        case .indefinitely:
            return "Never"
        case .onDate:
            return "On Date"
        case .after:
            return "After"
        }
    }

    private var shouldShowBottomPadding: Bool {
        repeatUntilOption == .indefinitely
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Repeat")
                    .foregroundColor(.primary)
                Spacer()
                Menu {
                    ForEach(RepeatOption.allCases, id: \.self) { option in
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
            .padding (.horizontal)

            if showRepeatOptions {
                if repeatOption == .custom {
                    Divider()
                        .padding(.leading)

                    HStack {
                        Text("Every")
                        Spacer()
                        TextField("", value: $customRepeatCount, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                            .multilineTextAlignment(.center)
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
                    .padding (.horizontal)

                }

                Divider()
                    .padding(.leading)

                if repeatOption != .never {
                    HStack {
                        Text("End repeat")
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
                                repeatUntilOption = .onDate
                            }) {
                                Text("On Date")
                                    .foregroundColor(repeatUntilOption == .onDate ? .gray : .primary)
                            }
                            Button(action: {
                                repeatUntilOption = .after
                            }) {
                                Text("After")
                                    .foregroundColor(repeatUntilOption == .after ? .gray : .primary)
                            }
                        } label: {
                            HStack {
                                Text(repeatUntilOptionDisplayText)
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding (.top, 6)
                    .padding (.horizontal)
                    .padding(.bottom, shouldShowBottomPadding ? 16 : 0)

                }


                switch repeatUntilOption {

                case .onDate:
                    Divider()
                        .padding(.leading)
                    
                    DatePicker("End Date", selection: $repeatUntil, displayedComponents: .date)
                    .padding(.bottom, 6)
                    .padding (.leading)
                    .padding (.trailing, 6)
                
                case .after:
                    Divider()
                        .padding(.leading)
                    
                    HStack {
                        Text("After")
                        Spacer()
                        TextField("", value: $repeatUntilCount, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                            .multilineTextAlignment(.center)
                        Text(repeatUntilCount > 1 ? repeatUnit : String(repeatUnit.dropLast()))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom)
                    .padding(.top, 4)
                    .padding(.horizontal)
                case .indefinitely:
                    EmptyView()
                }
            }
        }
        // .padding(.horizontal)
    }
}
