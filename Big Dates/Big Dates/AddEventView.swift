//
//  AddEventView.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import Foundation
import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var events: [Event]
    @State private var title = ""
    @State private var date = Date()
    @FocusState private var isTitleFocused: Bool  // Focus state for the title field

    var body: some View {
        NavigationView {
            Form {
                TextField("Event Title", text: $title)
                    .focused($isTitleFocused)  // Apply the focused state
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .navigationBarTitle("Add Event", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            }, trailing: Button("Save") {
                saveEvent()
            })
            .onAppear {
                isTitleFocused = true  // Automatically focus the title field when the view appears
            }
        }
    }
    
    private func saveEvent() {
        let newEvent = Event(title: title, date: date)
        events.append(newEvent)
        events.sort(by: { $0.date < $1.date })
        dismiss()
    }
}