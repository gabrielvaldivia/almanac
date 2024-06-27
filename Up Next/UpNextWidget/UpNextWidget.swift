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
                return upcomingEvents.filter { $0.category == category }
            }
        } else {
            return []
        }
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
        formatter.dateFormat = "MMMM d" // Updated date format to show full month name
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
            
            switch widgetFamily {
            
            // Small widget
            case .systemSmall:
                Spacer()
                let visibleEvents = entry.events.prefix(2)
                ForEach(visibleEvents) { event in
                    VStack(alignment: .leading) {
                        Text(event.date.relativeDate().capitalized)
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text(event.title)
                            .font(.subheadline)
                            .lineLimit(2)
                            .padding(.bottom, 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                }

            // Medium widget
            case .systemMedium:
                Spacer()
                let visibleEvents = entry.events.prefix(2)
                ForEach(visibleEvents) { event in
                    Spacer()
                    HStack(alignment: .top) {
                        Text(event.date.relativeDate().capitalized)
                            .foregroundColor(.gray)
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                        HStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(categoryColors[event.category ?? ""] ?? .gray)
                                .frame(width: 5)
                                .padding(.vertical, 1)
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .padding(.bottom, 0)
                                if let endDate = event.endDate {
                                    Text("\(event.date, formatter: dateFormatter) — \(endDate, formatter: dateFormatter) (\(Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1) days)")
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
            
            // Large widget
            case .systemLarge:
                let visibleEvents = entry.events.sorted(by: { $0.date < $1.date }).prefix(5)

                ForEach(visibleEvents) { event in
                    HStack(alignment: .top) {
                        Text(event.date.relativeDate().capitalized)
                            .foregroundColor(.gray)
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                            .padding(.vertical, 1)
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(categoryColors[event.category ?? ""] ?? .gray)
                                .frame(width: 4)
                                .padding(.vertical, 1)
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .padding(.bottom, 1)
                                if let endDate = event.endDate {
                                    Text("\(event.date, formatter: dateFormatter) — \(endDate, formatter: dateFormatter) (\(Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1) days)")
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
                        
                    } .padding(.bottom, 10)
                }
                Spacer()

            case .accessoryRectangular:
                let visibleEvents = entry.events.prefix(1)
                ForEach(visibleEvents) { event in
                    VStack(alignment: .leading) {
                        Text(event.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .padding(.bottom, 1)
                        if let endDate = event.endDate {
                            Text("\(event.date, formatter: dateFormatter) — \(endDate, formatter: dateFormatter) (\(Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1) days)")
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
            
            if entry.events.count > (widgetFamily == .systemLarge ? 5 : widgetFamily == .systemMedium ? 2 : 2) {
                Spacer()
                Text("\(entry.events.count - (widgetFamily == .systemLarge ? 5 : widgetFamily == .systemMedium ? 2 : 2)) more events")
                    .foregroundColor(.gray)
                    .font(.caption)
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
