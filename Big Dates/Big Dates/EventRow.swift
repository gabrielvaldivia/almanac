//
//  EventRow.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import SwiftUI

struct EventRow: View {
    var event: Event

    var body: some View {
        HStack {
            Text(event.title)
                .foregroundColor(.black)
            Spacer()
            Text(ContentView.dateFormatter.string(from: event.date))
                .foregroundColor(.gray)
        }
        .padding()
    }
}
