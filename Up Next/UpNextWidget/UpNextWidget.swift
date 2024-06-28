//
//  UpNextWidget.swift
//  UpNextWidget
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import Foundation
import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), events: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let events = loadEvents(for: configuration.category)
        return SimpleEntry(date: Date(), configuration: configuration, events: events)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let events = loadEvents(for: configuration.category)

        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration, events: events)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

    private func loadEvents(for category: String) -> [Event] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events"),
           let decoded = try? decoder.decode([Event].self, from: data) {
            let today = Calendar.current.startOfDay(for: Date())
            let upcomingEvents = decoded.filter { event in
                let eventDate = event.endDate ?? event.date
                return eventDate >= today
            }
            if category == "All Categories" {
                return upcomingEvents
            } else {
                return upcomingEvents.filter { event in
                    safeStringCompare(event.category, category)
                }
            }
        } else {
            return []
        }
    }

    private func safeStringCompare(_ str1: String?, _ str2: String?) -> Bool {
        return str1?.caseInsensitiveCompare(str2 ?? "") == .orderedSame
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let events: [Event]
}

struct UpNextWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // Updated date format to show full month name
        return formatter
    }()

    func fetchCategoryColors() -> [String: Color] {
        var categoryColors: [String: Color] = [:]
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "categories"),
           let decoded = try? JSONDecoder().decode([CategoryData].self, from: data) {
            for category in decoded {
                categoryColors[category.name] = category.color.color
            }
        }
        return categoryColors
    }

    var body: some View {
        let categoryColors = fetchCategoryColors()
        
        VStack(alignment: .leading) {
            Text("UP NEXT")
                .bold()
                .foregroundColor(.red)
                .font(.caption)
            
            if entry.events.isEmpty {
                Spacer()
                Text("No upcoming events")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.caption)
                Spacer ()
            } else {
                switch widgetFamily {
                
                // Small widget
                case .systemSmall:
                    Spacer()
                    let visibleEvents = entry.events.sorted(by: { $0.date < $1.date }).prefix(2) // Sort events by date
                    VStack(alignment: .leading) {
                        ForEach(visibleEvents) { event in
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(categoryColors[event.category ?? ""] ?? .gray)
                                    .frame(width: 4)
                                    .padding(.vertical, 1)
                                VStack {
                                    Text(event.date.relativeDate(to: event.endDate))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(event.title)
                                        .fontWeight(.medium)
                                        .font(.footnote)
                                        .lineLimit(2)
                                        .padding(.bottom, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                // Medium widget
                case .systemMedium:
                    Spacer()
                    let visibleEvents = entry.events.sorted(by: { $0.date < $1.date }).prefix(2) // Sort events by date
                    let groupedEvents = Dictionary(grouping: visibleEvents, by: { event in
                        if event.date <= Date() && (event.endDate ?? event.date) >= Date() {
                            return "Today"
                        } else {
                            return event.date.relativeDate()
                        }
                    })
                    let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                        let date1 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key1)))
                        let date2 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key2)))
                        return date1 < date2
                    }

                    ForEach(sortedKeys, id: \.self) { key in
                        HStack(alignment: .top) {
                            Text(key)
                                .frame(width: 70, alignment: .leading)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 4)
                            VStack(alignment: .leading) {
                                ForEach(groupedEvents[key]!) { event in 
                                    HStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(categoryColors[event.category ?? ""] ?? .gray)
                                            .frame(width: 4)
                                            .padding(.vertical, 1)
                                        VStack(alignment: .leading) {
                                            Text(event.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .lineLimit(2)
                                                .padding(.bottom, 0)
                                            if let endDate = event.endDate {
                                                let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day! + 1
                                                let dayText = daysRemaining == 1 ? "day" : "days"
                                                Text("\(event.date, formatter: dateFormatter) — \(endDate, formatter: dateFormatter) (\(daysRemaining) \(dayText) left)")
                                                    .foregroundColor(.gray)
                                                    .font(.caption)
                                            } else {
                                                Text(event.date, formatter: dateFormatter)
                                                    .foregroundColor(.gray)
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 6)
                                }
                            }
                        }
                    }

                // Large widget
                case .systemLarge:
                    let visibleEvents = entry.events.sorted(by: { $0.date < $1.date }).prefix(5) // Sort events by date
                    let groupedEvents = Dictionary(grouping: visibleEvents, by: { event in
                        if event.date <= Date() && (event.endDate ?? event.date) >= Date() {
                            return "Today"
                        } else {
                            return event.date.relativeDate()
                        }
                    })
                    let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                        let date1 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key1)))
                        let date2 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key2)))
                        return date1 < date2
                    }

                    ForEach(sortedKeys, id: \.self) { key in
                        HStack(alignment: .top) {
                            Text(key)
                                .frame(width: 70, alignment: .leading)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 4)
                            VStack(alignment: .leading) {
                                ForEach(groupedEvents[key]!) { event in 
                                    VStack(alignment: .leading) {
                                        HStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(categoryColors[event.category ?? ""] ?? .gray)
                                                .frame(width: 4)
                                                .padding(.vertical, 1)
                                            VStack(alignment: .leading) {
                                                Text(event.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .lineLimit(2)
                                                    .padding(.bottom, 1)
                                                if let endDate = event.endDate {
                                                    let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day! + 1
                                                    let dayText = daysRemaining == 1 ? "day" : "days"
                                                    Text("\(event.date, formatter: dateFormatter) — \(endDate, formatter: dateFormatter) (\(daysRemaining) \(dayText) left)")
                                                        .foregroundColor(.gray)
                                                        .font(.caption)
                                                } else {
                                                    Text(event.date, formatter: dateFormatter)
                                                        .foregroundColor(.gray)
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading)
                                    }
                                } 
                            } .padding(.bottom, 10)
                        }
                    } 
                    Spacer ()

                case .accessoryRectangular:
                    let visibleEvents = entry.events.prefix(1)
                    ForEach(visibleEvents) { event in
                        VStack(alignment: .leading) {
                            Text(event.title)
                                .font(.subheadline)
                                .lineLimit(1)
                                .padding(.bottom, 1)
                            if let endDate = event.endDate {
                                let daysRemaining = Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1
                                let dayText = daysRemaining == 1 ? "day" : "days"
                                Text("\(event.date, formatter: dateFormatter) — \(endDate, formatter: dateFormatter) (\(daysRemaining) \(dayText) left)")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            } else {
                                Text(event.date, formatter: dateFormatter)
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    }
                    
                default:
                    Text("Unsupported widget size")
                }
                
                let remainingEventsCount = entry.events.count - (widgetFamily == .systemLarge ? 5 : widgetFamily == .systemMedium ? 2 : 2)
                if remainingEventsCount > 0 {
                    Spacer()
                    Text("\(remainingEventsCount) more \(remainingEventsCount == 1 ? "event" : "events")")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UpNextWidget: Widget {
    let kind: String = "UpNextWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            UpNextWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.category = "All Categories"
        return intent
    }
}




