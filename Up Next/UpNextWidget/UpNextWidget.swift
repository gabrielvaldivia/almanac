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
        var entries: [SimpleEntry] = []
        let events = EventLoader.loadEvents(for: configuration.category)

        let currentDate = Date()
        for hourOffset in 0..<5 {
            let entryDate = Calendar.current.date(
                byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration, events: events)
            entries.append(entry)
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
    @EnvironmentObject var appData: AppData

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    func fetchCategoryColors() -> [String: Color] {
        var categoryColors: [String: Color] = [:]
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
            let data = sharedDefaults.data(forKey: "categories"),
            let decoded = try? JSONDecoder().decode([CategoryData].self, from: data)
        {
            for category in decoded {
                categoryColors[category.name] = category.color.color
            }
        }
        return categoryColors
    }

    var body: some View {
        let categoryColors = fetchCategoryColors()
        let defaultCategoryColor = appData.defaultCategoryColor

        let filteredEvents = entry.events.filter { event in
            let twelveMonthsFromNow = Calendar.current.date(
                byAdding: .month, value: 12, to: Date())!
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
                                            event.category != nil
                                                ? (categoryColors[event.category ?? ""] ?? .gray)
                                                : defaultCategoryColor
                                        )
                                        .frame(width: 4)
                                        .padding(.vertical, 1)
                                    VStack(alignment: .leading) {
                                        Text(
                                            calculateTimeRemaining(
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
                            if event.date <= Date() && (event.endDate ?? event.date) >= Date() {
                                return "Today"
                            } else if let endDate = event.endDate,
                                Calendar.current.isDateInToday(endDate)
                            {
                                return "Today"
                            } else {
                                return event.date.relativeDate()
                            }
                        })
                    let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                        let date1 = Date().addingTimeInterval(
                            TimeInterval(daysFromRelativeDate(key1)))
                        let date2 = Date().addingTimeInterval(
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
                                                event.category != nil
                                                    ? (categoryColors[event.category ?? ""] ?? .gray)
                                                    : defaultCategoryColor
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
                                                calculateTimeRemaining(
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
                            if event.date <= Date() && (event.endDate ?? event.date) >= Date() {
                                return "Today"
                            } else if let endDate = event.endDate,
                                Calendar.current.isDateInToday(endDate)
                            {
                                return "Today"
                            } else {
                                return event.date.relativeDate()
                            }
                        })
                    let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                        let date1 = Date().addingTimeInterval(
                            TimeInterval(daysFromRelativeDate(key1)))
                        let date2 = Date().addingTimeInterval(
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
                                                event.category != nil
                                                    ? (categoryColors[event.category ?? ""] ?? .gray)
                                                    : defaultCategoryColor
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
                                                calculateTimeRemaining(
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
                            Text(calculateTimeRemaining(from: event.date, to: event.endDate))
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
        let twelveMonthsFromNow = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
        let futureEvents = events.filter { $0.date <= twelveMonthsFromNow }
        return max(0, futureEvents.count - visibleCount)
    }

    // Remove widget-specific implementation and use the shared one from Utilities
    private func calculateTimeRemaining(from startDate: Date, to endDate: Date?) -> String {
        guard let endDate = endDate else {
            return dateFormatter.string(from: startDate)
        }

        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let startOfEndDate = calendar.startOfDay(for: endDate)

        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)

        // Calculate total duration of the event (using start of days)
        let duration =
            calendar.dateComponents([.day], from: startOfStartDate, to: startOfEndDate).day! + 1
        let durationText = duration == 1 ? "day" : "days"

        // If start date is after today, show duration
        if startOfStartDate > now {
            if calendar.isDate(startDate, inSameDayAs: endDate) {
                return "\(startDateString) (\(duration) \(durationText))"
            } else {
                return "\(startDateString) → \(endDateString) (\(duration) \(durationText))"
            }
        }

        // For ongoing or past events, show days remaining
        let daysRemaining = calendar.dateComponents([.day], from: now, to: startOfEndDate).day! + 1
        let dayText = daysRemaining == 1 ? "day" : "days"

        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return "\(startDateString) (\(daysRemaining) \(dayText) left)"
        } else {
            return "\(startDateString) → \(endDateString) (\(daysRemaining) \(dayText) left)"
        }
    }
}

struct UpNextWidget: Widget {
    let kind: String = "UpNextWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()
        ) { entry in
            UpNextWidgetEntryView(entry: entry)
                .environmentObject(AppData.shared)  // Pass appData as environment object
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Up Next")
        .description("Shows upcoming events.")
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
        NextEventEntry(
            date: Date(),
            event: Event(title: "Sample Event", date: Date(), color: CodableColor(color: .blue)))
    }

    func getSnapshot(in context: Context, completion: @escaping (NextEventEntry) -> Void) {
        let events = EventLoader.loadEvents(for: ConfigurationAppIntent().category)
        let twelveMonthsFromNow = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
        let nextEvent =
            events.filter { event in
                let now = Date()
                let startOfDay = Calendar.current.startOfDay(for: now)
                return (event.date >= startOfDay || (event.endDate ?? event.date) >= now)
                    && event.date <= twelveMonthsFromNow
            }.sorted { $0.date < $1.date }.first
            ?? Event(title: "No upcoming events", date: Date(), color: CodableColor(color: .gray))

        let entry = NextEventEntry(date: Date(), event: nextEvent)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextEventEntry>) -> Void)
    {
        var entries: [NextEventEntry] = []

        let events = EventLoader.loadEvents(for: ConfigurationAppIntent().category)
        let twelveMonthsFromNow = Calendar.current.date(byAdding: .month, value: 12, to: Date())!
        let nextEvent =
            events.filter { event in
                let now = Date()
                let startOfDay = Calendar.current.startOfDay(for: now)
                return (event.date >= startOfDay || (event.endDate ?? event.date) >= now)
                    && event.date <= twelveMonthsFromNow
            }.sorted { $0.date < $1.date }.first
            ?? Event(title: "No upcoming events", date: Date(), color: CodableColor(color: .gray))

        let entry = NextEventEntry(date: Date(), event: nextEvent)
        entries.append(entry)

        // Set the timeline policy to refresh more frequently
        let timeline = Timeline(
            entries: entries, policy: .after(Date().addingTimeInterval(60 * 15)))  // Refresh every 15 minutes
        completion(timeline)
    }
}

struct NextEventEntry: TimelineEntry {
    let date: Date
    let event: Event
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
            if entry.event.title == "No upcoming events" {
                Spacer()
                Text("No upcoming events")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.caption)
                Spacer()
            } else {
                Text(dateFormatter.string(from: entry.event.date))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text(entry.event.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 1)
                Text(calculateTimeRemaining(from: entry.event.date, to: entry.event.endDate))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .widgetURL(URL(string: "upnext://editWidget"))
    }

    private func calculateTimeRemaining(from startDate: Date, to endDate: Date?) -> String {
        guard let endDate = endDate else {
            return dateFormatter.string(from: startDate)
        }

        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let startOfEndDate = calendar.startOfDay(for: endDate)

        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)

        // Calculate total duration of the event (using start of days)
        let duration =
            calendar.dateComponents([.day], from: startOfStartDate, to: startOfEndDate).day! + 1
        let durationText = duration == 1 ? "day" : "days"

        // If start date is after today, show duration
        if startOfStartDate > now {
            if calendar.isDate(startDate, inSameDayAs: endDate) {
                return "\(startDateString) (\(duration) \(durationText))"
            } else {
                return "\(startDateString) → \(endDateString) (\(duration) \(durationText))"
            }
        }

        // For ongoing or past events, show days remaining
        let daysRemaining = calendar.dateComponents([.day], from: now, to: startOfEndDate).day! + 1
        let dayText = daysRemaining == 1 ? "day" : "days"

        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return "\(startDateString) (\(daysRemaining) \(dayText) left)"
        } else {
            return "\(startDateString) → \(endDateString) (\(daysRemaining) \(dayText) left)"
        }
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
