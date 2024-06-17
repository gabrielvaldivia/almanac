//
//  EventDetailView.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import SwiftUI

struct EventDetailView: View {
    @Binding var event: Event
    var onDelete: () -> Void
    @Environment(\.dismiss) var dismiss  

    var body: some View {
        NavigationView {
            Form {
                TextField("Event Title", text: $event.title)
                DatePicker("Event Date", selection: $event.date, displayedComponents: .date)
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Save") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
