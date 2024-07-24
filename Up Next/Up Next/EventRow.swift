//
//  EventRow.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

// EVENT ROW
struct EventRow: View {
    var event: Event
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var selectedCategory: String?
    @Binding var showEditSheet: Bool
    var categories: [(name: String, color: Color)]
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appData: AppData

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    private func getDurationText(start: Date, end: Date?) -> String {
        guard let end = end else { return "" }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        guard let days = components.day, days > 0 else { return "" }
        
        let now = Date()
        if now >= start && now <= end {
            let remainingComponents = calendar.dateComponents([.day], from: now, to: end)
            if let remainingDays = remainingComponents.day, remainingDays > 0 {
                return "(\(remainingDays) day\(remainingDays == 1 ? "" : "s") left)"
            }
        }
        
        return "(\(days) day\(days == 1 ? "" : "s"))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: appData.eventStyle == "naked" ? 8 : 20) {
            // Event Style Indicator
            if appData.eventStyle == "naked" {
                RoundedRectangle(cornerRadius: 3)
                    .fill(event.color.color)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
            VStack(alignment: .leading) {
                // Event Title
                HStack {
                    Text(event.title)
                        .roundedFont(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? .white : (appData.eventStyle == "naked" ? .primary : event.color.color))
                        .padding (.bottom, 2)
                    Spacer()
                }
                
                // Event Date(s)
                if let endDate = event.endDate {
                    Text("\(dateFormatter.string(from: event.date)) → \(dateFormatter.string(from: endDate)) \(getDurationText(start: event.date, end: endDate))")
                        .roundedFont(.footnote)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : (appData.eventStyle == "naked" ? .secondary : event.color.color.opacity(0.7)))
                } else {
                    Text(dateFormatter.string(from: event.date))
                        .roundedFont(.footnote)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : (appData.eventStyle == "naked" ? .secondary : event.color.color.opacity(0.7)))
                }
                
                // Repeat Information
                if event.repeatOption != .never {
                    if event.repeatOption == .custom, let count = event.customRepeatCount, let unit = event.repeatUnit {
                        let unitText = count == 1 ? String(unit.lowercased().dropLast()) : unit.lowercased()
                        Text("Repeats every \(count) \(unitText)")
                            .roundedFont(.footnote)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : (appData.eventStyle == "naked" ? .secondary : event.color.color.opacity(0.7)))
                    } else {
                        Text("Repeats \(event.repeatOption.rawValue.lowercased())")
                            .roundedFont(.footnote)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : (appData.eventStyle == "naked" ? .secondary : event.color.color.opacity(0.7)))
                    }
                }
            }
            .padding(.vertical, appData.eventStyle == "naked" ? 4 : 12)
            .padding(.horizontal, appData.eventStyle == "naked" ? 0 : 16)
            .background(
                Group {
                    // Background Style
                    if appData.eventStyle == "bubbly" {
                        event.color.color.opacity(colorScheme == .light ? 0.1 : 0.3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(event.color.color.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(event.color.color.opacity(0.4), lineWidth: 4)
                                    .blur(radius: 4)
                                    .mask(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [.black, .clear]),
                                                    startPoint: .bottom,
                                                    endPoint: .top
                                                )
                                            )
                                    )
                            )
                    } else if appData.eventStyle == "flat" {
                        event.color.color.opacity(colorScheme == .light ? 0.1 : 0.3)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(appData.eventStyle == "naked" ? 0 : 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: appData.eventStyle == "naked" ? 0 : 12))
    }
}