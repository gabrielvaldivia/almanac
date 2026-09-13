//
//  UpNextWidget.swift
//  UpNextWidget
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import Foundation
import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), events: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async
        -> SimpleEntry
    {
        let events = EventLoader.loadEvents(for: configuration.category)
        return SimpleEntry(date: Date(), configuration: configuration, events: events)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
        SimpleEntry
    > {
        let entries = WidgetEvents.entryDates().map { date in
            SimpleEntry(date: date, configuration: configuration, events: EventLoader.loadEvents(for: configuration.category, at: date))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let events: [Event]
}

struct UpNextWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    func fetchCategoryColors() -> [String: Color] {
        var categoryColors: [String: Color] = [:]
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
            let data = sharedDefaults.data(forKey: "categories"),
            let decoded = try? CategoryStorage.decode(data)
        {
            for category in decoded {
                categoryColors[category.name] = category.color.color
            }
        }
        return categoryColors
    }

    var body: some View {
        let categoryColors = fetchCategoryColors()
        let defaultCategoryColor = categoryColors[AppPreferences.shared.string(forKey: "defaultCategory") ?? ""] ?? .blue

        let filteredEvents = entry.events.filter { event in
            let twelveMonthsFromNow = Calendar.current.date(
                byAdding: .month, value: 12, to: entry.date)!
            return event.date <= twelveMonthsFromNow
        }

        VStack(alignment: .leading) {
            HStack {
                Text("UP NEXT")
                    .bold()
                    .foregroundColor(.red)
                    .font(.caption)
                Spacer()
                Link(destination: URL(string: "upnext://addEvent")!) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(defaultCategoryColor)  // Use default category color
                        .font(.title3)
                }
            }

            if filteredEvents.isEmpty {
                Spacer()
                Text("No upcoming events")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.caption)
                Spacer()
            } else {
                switch widgetFamily {

                // Small widget
                case .systemSmall:
                    let visibleEvents = filteredEvents.sorted(by: { $0.date < $1.date }).prefix(2)  // Sort events by date
                    VStack {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(visibleEvents.enumerated()), id: \.offset) {
                                index, event in
                                HStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            event.color.color
                                        )
                                        .frame(width: 4)
                                        .padding(.vertical, 1)
                                    VStack(alignment: .leading) {
                                        Text(
                                            rangeDescription(
                                                from: event.date, to: event.endDate)
                                        )
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        Text(event.title)
                                            .fontWeight(.medium)
                                            .font(.footnote)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Spacer()
                        }

                        let remainingEventsCount = getRemainingEventsCount(
                            events: filteredEvents, visibleCount: 2)
                        if remainingEventsCount > 0 {
                            Text(
                                "\(remainingEventsCount) more \(remainingEventsCount == 1 ? "event" : "events")"
                            )
                            .foregroundColor(.gray)
                            .font(.caption)
                        }
                    }

                // Medium widget
                case .systemMedium:
                    let visibleEvents = filteredEvents.sorted(by: { $0.date < $1.date }).prefix(2)  // Sort events by date
                    let groupedEvents = Dictionary(
                        grouping: visibleEvents,
                        by: { event in
                            if event.date <= entry.date && (event.endDate ?? event.date) >= entry.date {
                                return "Today"
                            } else if let endDate = event.endDate,
                                Calendar.current.isDate(endDate, inSameDayAs: entry.date)
                            {
                                return "Today"
                            } else {
                                return event.date.relativeDate(now: entry.date)
                            }
                        })
                    let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                        let date1 = entry.date.addingTimeInterval(
                            TimeInterval(daysFromRelativeDate(key1)))
                        let date2 = entry.date.addingTimeInterval(
                            TimeInterval(daysFromRelativeDate(key2)))
                        return date1 < date2
                    }

                    ForEach(sortedKeys, id: \.self) { key in
                        HStack(alignment: .top) {
                            Text(key.capitalized)
                                .frame(width: 70, alignment: .leading)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 2)
                            VStack(alignment: .leading) {
                                ForEach(Array(groupedEvents[key]!.enumerated()), id: \.offset) {
                                    index, event in
                                    HStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                event.color.color
                                            )
                                            .frame(width: 4)
                                            .padding(.vertical, 1)
                                        VStack(alignment: .leading) {
                                            Text(event.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .lineLimit(2)
                                                .padding(.bottom, 0)
                                            Text(
                                                rangeDescription(
                                                    from: event.date, to: event.endDate)
                                            )
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading)
                                    .padding(.bottom, 6)
                                }
                            }
                        }
                    }

                // Large widget
                case .systemLarge:
                    let visibleEvents = filteredEvents.sorted(by: { $0.date < $1.date }).prefix(5)  // Sort events by date
                    let groupedEvents = Dictionary(
                        grouping: visibleEvents,
                        by: { event in
                            if event.date <= entry.date && (event.endDate ?? event.date) >= entry.date {
                                return "Today"
                            } else if let endDate = event.endDate,
                                Calendar.current.isDate(endDate, inSameDayAs: entry.date)
                            {
                                return "Today"
                            } else {
                                return event.date.relativeDate(now: entry.date)
                            }
                        })
                    let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                        let date1 = entry.date.addingTimeInterval(
                            TimeInterval(daysFromRelativeDate(key1)))
                        let date2 = entry.date.addingTimeInterval(
                            TimeInterval(daysFromRelativeDate(key2)))
                        return date1 < date2
                    }

                    ForEach(sortedKeys, id: \.self) { key in
                        HStack(alignment: .top) {
                            Text(key.capitalized)
                                .frame(width: 70, alignment: .leading)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 2)
                            VStack(alignment: .leading) {
                                ForEach(Array(groupedEvents[key]!.enumerated()), id: \.offset) {
                                    index, event in
                                    HStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                event.color.color
                                            )
                                            .frame(width: 4)
                                            .padding(.vertical, 1)
                                        VStack(alignment: .leading) {
                                            Text(event.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .lineLimit(2)
                                                .padding(.bottom, 1)
                                            Text(
                                                rangeDescription(
                                                    from: event.date, to: event.endDate)
                                            )
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading)
                                    .padding(.bottom, 6)
                                }
                            }
                        }.padding(.bottom, 10)
                    }

                // Next Event widget
                case .accessoryRectangular:
                    let visibleEvents = filteredEvents.prefix(1)
                    ForEach(visibleEvents) { event in
                        VStack(alignment: .leading) {
                            Text(event.title)
                                .font(.subheadline)
                                .lineLimit(1)
                                .padding(.bottom, 1)
                            Text(rangeDescription(from: event.date, to: event.endDate))
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                    }

                    let remainingEventsCount = getRemainingEventsCount(
                        events: filteredEvents, visibleCount: 1)
                    if remainingEventsCount > 0 {
                        Spacer()
                        Text(
                            "\(remainingEventsCount) more \(remainingEventsCount == 1 ? "event" : "events")"
                        )
                        .foregroundColor(.gray)
                        .font(.caption)
                    }

                default:
                    Text("Unsupported widget size")
                }

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "upnext://widgetTapped"))  // Add this line to handle widget tap
    }

    // Add this helper function to calculate remaining events count
    private func getRemainingEventsCount(events: [Event], visibleCount: Int) -> Int {
        let twelveMonthsFromNow = Calendar.current.date(byAdding: .month, value: 12, to: entry.date)!
        let futureEvents = events.filter { $0.date <= twelveMonthsFromNow }
        return max(0, futureEvents.count - visibleCount)
    }

    // Remove widget-specific implementation and use the shared one from Utilities
    private func rangeDescription(from startDate: Date, to endDate: Date?) -> String {
        EventDateText.range(start: startDate, end: endDate, reference: entry.date)
    }
}

struct UpNextWidget: Widget {
    let kind: String = "UpNextWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()
        ) { entry in
            UpNextWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Up Next")
        .description("Shows upcoming events.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

extension ConfigurationAppIntent {

    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.category = "All Categories"
        return intent
    }
}

// New Next Event Widget
struct NextEventProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextEventEntry {
        NextEventEntry(date: Date(), event: Event(title: "Sample Event", date: Date(), color: CodableColor(color: .blue)))
    }
    func getSnapshot(in context: Context, completion: @escaping (NextEventEntry) -> Void) {
        let now = Date()
        completion(NextEventEntry(date: now, event: EventLoader.loadEvents(at: now).first))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextEventEntry>) -> Void) {
        let entries = WidgetEvents.entryDates().map { NextEventEntry(date: $0, event: EventLoader.loadEvents(at: $0).first) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NextEventEntry: TimelineEntry {
    let date: Date
    let event: Event?
}

struct NextEventWidgetEntryView: View {
    var entry: NextEventProvider.Entry

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading) {
            if let event = entry.event {
                Text(dateFormatter.string(from: event.date))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(event.color.color)
                Spacer()
                Text(event.title).font(.headline).lineLimit(3)
                Text(rangeDescription(from: event.date, to: event.endDate))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Spacer()
                Text("No upcoming events").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(entry.event.map { DeepLink.eventURL($0.id) } ?? URL(string: "upnext://home"))
    }

    private func rangeDescription(from startDate: Date, to endDate: Date?) -> String {
        EventDateText.range(start: startDate, end: endDate, reference: entry.date)
    }
}

struct NextEventWidget: Widget {
    let kind: String = "NextEventWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextEventProvider()) { entry in
            NextEventWidgetEntryView(entry: entry)
                .containerBackground(Color(UIColor.systemBackground), for: .widget)
        }
        .configurationDisplayName("Next Event")
        .description("Shows the next upcoming event.")
        .supportedFamilies([.systemSmall])
    }
}
