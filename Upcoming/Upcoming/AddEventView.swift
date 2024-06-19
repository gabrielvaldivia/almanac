//
//  AddEventView.swift
//  Upcoming
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import Foundation
import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var events: [Event]
    var onSave: () -> Void  // Closure to handle saving

    @State private var title: String = ""
    @State private var date: Date = Date()
    @FocusState private var isTitleFocused: Bool  // Declare a FocusState to manage focus

    var body: some View {
        NavigationView {
            // Form
            Form {
                TextField("Event Title", text: $title)
                    .focused($isTitleFocused)  // Bind the focus state to the text field
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }

            // Navigation bar
            .navigationTitle("Add Event")
                .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            }, trailing: Button("Save") {
                let newEvent = Event(title: title, date: date)
                events.append(newEvent)
                events.sort()
                onSave()  // Call the onSave closure
                dismiss()
            })
            .onAppear {
                isTitleFocused = true  // Automatically focus the title text field when the view appears
            }
        }
    }
}