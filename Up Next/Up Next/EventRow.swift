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
        return calculateTimeRemaining(from: start, to: end)
    }

    private func getRepeatText() -> String {
        switch event.repeatOption {
        case .never:
            return ""
        case .daily:
            return "Repeats daily"
        case .weekly:
            return "Repeats weekly"
        case .monthly:
            return "Repeats monthly"
        case .yearly:
            return "Repeats yearly"
        case .custom:
            if let count = event.customRepeatCount, let unit = event.repeatUnit {
                let unitString = count == 1 ? singularForm(of: unit) : pluralForm(of: unit)
                return "Repeats every \(count) \(unitString)"
            }
            return ""
        }
    }

    private func singularForm(of unit: String) -> String {
        switch unit.lowercased() {
        case "day", "days": return "Day"
        case "week", "weeks": return "Week"
        case "month", "months": return "Month"
        case "year", "years": return "Year"
        default: return unit.capitalized
        }
    }

    private func pluralForm(of unit: String) -> String {
        switch unit.lowercased() {
        case "day", "days": return "days"
        case "week", "weeks": return "weeks"
        case "month", "months": return "months"
        case "year", "years": return "years"
        default: return unit.lowercased() + "s"
        }
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
                        .foregroundColor(
                            colorScheme == .dark
                                ? .white
                                : (appData.eventStyle == "naked" ? .primary : event.color.color)
                        )
                        .padding(.bottom, 1)
                    Spacer()
                }

                // Event Date(s) and Repeat Information
                Text(eventDateAndRepeatText)
                    .roundedFont(.footnote)
                    .foregroundColor(
                        colorScheme == .dark
                            ? Color.white.opacity(0.5)
                            : (appData.eventStyle == "naked"
                                ? .secondary : event.color.color.opacity(0.7))
                    )
                    .fixedSize(horizontal: false, vertical: true)
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
        .onTapGesture {
            selectedEvent = event
            newEventTitle = event.title
            newEventDate = event.date
            newEventEndDate =
                event.endDate ?? Calendar.current.date(byAdding: .day, value: 1, to: event.date)
                ?? event.date
            showEndDate = event.endDate != nil
            selectedCategory = event.category
            showEditSheet = true
        }
    }

    private var eventDateAndRepeatText: String {
        var text = calculateTimeRemaining(from: event.date, to: event.endDate)
        if event.repeatOption != .never {
            text += " • \(getRepeatText())"
        }
        return text
    }

    private func calculateTimeRemaining(from startDate: Date, to endDate: Date?) -> String {
        guard let endDate = endDate else {
            return dateFormatter.string(from: startDate)
        }
        let now = Date()
        let calendar = Calendar.current
        let daysRemaining = calendar.dateComponents([.day], from: now, to: endDate).day! + 1
        let dayText = daysRemaining == 1 ? "day" : "days"

        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)

        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return "\(startDateString) (\(daysRemaining) \(dayText) left)"
        } else {
            return "\(startDateString) → \(endDateString) (\(daysRemaining) \(dayText) left)"
        }
    }
}

extension RepeatOption {
    var shorthand: String {
        switch self {
        case .daily: return "d"
        case .weekly: return "w"
        case .monthly: return "m"
        case .yearly: return "y"
        case .never, .custom: return ""
        }
    }
}
