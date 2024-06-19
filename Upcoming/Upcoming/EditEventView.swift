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
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            TextField("Event Title", text: $event.title)
            DatePicker("Date", selection: $event.date, displayedComponents: .date)
            Button("Save") {
                dismiss()
            }
        }
    }
}
