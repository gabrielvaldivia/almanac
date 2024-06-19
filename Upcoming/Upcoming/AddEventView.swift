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
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationView {
            Form {
                Section { 
                    TextField("Event Title", text: $title)
                        .focused($isTitleFocused)
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)  // Set the title display mode to inline
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            }, trailing: Button("Save") {
                let newEvent = Event(title: title, date: date)
                events.append(newEvent)
                events.sort()
                onSave()  // Call the onSave closure
                dismiss()
            })
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}