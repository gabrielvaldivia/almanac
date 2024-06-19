//
//  EditEventView.swift
//  Upcoming
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import Foundation
import SwiftUI

struct EditEventView: View {
    @Binding var event: Event
    var onSave: (Event) -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTitleFocused: Bool  // Declare a FocusState to manage focus

    var body: some View {

        // Form
        Form {
            TextField("Event Title", text: $event.title)
                .focused($isTitleFocused)  // Bind the focus state to the TextField
            DatePicker("Date", selection: $event.date, displayedComponents: .date)
            Button("Save") {
                onSave(event)
                dismiss()
            }
        }

        .onAppear {
            isTitleFocused = true  // Automatically focus the title text field when the view appears
        }
    }
}