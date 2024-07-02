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
    @EnvironmentObject var appData: AppData

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d" // Updated date format to show full month name
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
        let defaultCategoryColor = appData.defaultCategoryColor
        
        VStack(alignment: .leading) {
            HStack {
                Text("UP NEXT")
                    .bold()
                    .foregroundColor(.red)
                    .font(.caption)
                Spacer()
                Link(destination: URL(string: "upnext://addEvent")!) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(defaultCategoryColor) // Use default category color
                        .font(.title3)
                }
            }
            
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
                    let visibleEvents = entry.events.sorted(by: { $0.date < $1.date }).prefix(2) // Sort events by date
                    VStack(alignment: .leading) {
                        ForEach(Array(visibleEvents.enumerated()), id: \.offset) { index, event in
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(categoryColors[event.category ?? ""] ?? .gray)
                                    .frame(width: 4)
                                    .padding(.vertical, 1)
                                VStack {
                                    Text(event.date.relativeDate(to: event.endDate).capitalized)
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
                            .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading) // Set max height
                        }
                    }
                    Spacer()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                // Medium widget
                case .systemMedium:
                    let visibleEvents = entry.events.sorted(by: { $0.date < $1.date }).prefix(2) // Sort events by date
                    let groupedEvents = Dictionary(grouping: visibleEvents, by: { event in
                        if event.date <= Date() && (event.endDate ?? event.date) >= Date() {
                            return "Today"
                        } else if let endDate = event.endDate, Calendar.current.isDateInToday(endDate) {
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
                            Text(key.capitalized)
                                .frame(width: 70, alignment: .leading)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 2)
                            VStack(alignment: .leading) {
                                ForEach(Array(groupedEvents[key]!.enumerated()), id: \.offset) { index, event in
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
                                    .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading) // Set max height
                                    .padding(.bottom, 6)
                                }
                            }
                        }
                    }
                    Spacer()

                // Large widget
                case .systemLarge:
                    let visibleEvents = entry.events.sorted(by: { $0.date < $1.date }).prefix(5) // Sort events by date
                    let groupedEvents = Dictionary(grouping: visibleEvents, by: { event in
                        if event.date <= Date() && (event.endDate ?? event.date) >= Date() {
                            return "Today"
                        } else if let endDate = event.endDate, Calendar.current.isDateInToday(endDate) {
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
                            Text(key.capitalized)
                                .frame(width: 70, alignment: .leading)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 2)
                            VStack(alignment: .leading) {
                                ForEach(Array(groupedEvents[key]!.enumerated()), id: \.offset) { index, event in
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
                                                    let daysDuration = Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1
                                                    let dayText = daysDuration == 1 ? "day" : "days"
                                                    if event.date > Date() {
                                                        Text("\(event.date, formatter: dateFormatter) — \(endDate, formatter: dateFormatter) (\(daysDuration) \(dayText))")
                                                            .foregroundColor(.gray)
                                                            .font(.caption)
                                                    } else {
                                                        Text("\(event.date, formatter: dateFormatter) — \(endDate, formatter: dateFormatter) (\(daysDuration) \(dayText) left)")
                                                            .foregroundColor(.gray)
                                                            .font(.caption)
                                                    }
                                                } else {
                                                    Text(event.date, formatter: dateFormatter)
                                                        .foregroundColor(.gray)
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading) // Set max height
                                    }
                                }
                            } .padding(.bottom, 10)
                        }
                    }
                    Spacer()

                // Next Event widget
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
                .environmentObject(AppData.shared) // Pass appData as environment object
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
        NextEventEntry(date: Date(), event: Event(title: "Sample Event", date: Date(), color: CodableColor(color: .blue)))
    }

    func getSnapshot(in context: Context, completion: @escaping (NextEventEntry) -> ()) {
        let entry = NextEventEntry(date: Date(), event: Event(title: "Sample Event", date: Date(), color: CodableColor(color: .blue)))
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextEventEntry>) -> ()) {
        var entries: [NextEventEntry] = []

        // Fetch events from UserDefaults or your data source
        let events = loadEvents()
        if let nextEvent = events.filter({ event in
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            return event.date >= startOfDay || (event.endDate ?? event.date) >= now
        }).sorted(by: { $0.date < $1.date }).first {
            let entry = NextEventEntry(date: Date(), event: nextEvent)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func loadEvents() -> [Event] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events"),
           let decoded = try? decoder.decode([Event].self, from: data) {
            return decoded
        } else {
            return []
        }
    }
}

struct NextEventEntry: TimelineEntry {
    let date: Date
    let event: Event
}

struct NextEventWidgetEntryView : View {
    var entry: NextEventProvider.Entry

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.event.date.relativeDate(to: entry.event.endDate).capitalized)
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
            Text(entry.event.date, formatter: dateFormatter)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct NextEventWidget: Widget {
    let kind: String = "NextEventWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextEventProvider()) { entry in
            NextEventWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Event")
        .description("Shows the next upcoming event.")
        .supportedFamilies([.systemSmall])
    }
}

// New This Year Widget
// struct ThisYearProvider: TimelineProvider {
//     func placeholder(in context: Context) -> ThisYearEntry {
//         ThisYearEntry(date: Date(), events: [])
//     }

//     func getSnapshot(in context: Context, completion: @escaping (ThisYearEntry) -> ()) {
//         let entry = ThisYearEntry(date: Date(), events: [])
//         completion(entry)
//     }

//     func getTimeline(in context: Context, completion: @escaping (Timeline<ThisYearEntry>) -> ()) {
//         var entries: [ThisYearEntry] = []

//         // Fetch events from UserDefaults or your data source
//         let events = loadEvents()
//         let entry = ThisYearEntry(date: Date(), events: events)
//         entries.append(entry)

//         let timeline = Timeline(entries: entries, policy: .atEnd)
//         completion(timeline)
//     }

//     private func loadEvents() -> [Event] {
//         let decoder = JSONDecoder()
//         decoder.dateDecodingStrategy = .iso8601
//         if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
//            let data = sharedDefaults.data(forKey: "events"),
//            let decoded = try? decoder.decode([Event].self, from: data) {
//             return decoded
//         } else {
//             return []
//         }
//     }
// }

// struct ThisYearEntry: TimelineEntry {
//     let date: Date
//     let events: [Event]
// }

// struct ThisYearWidgetEntryView : View {
//     var entry: ThisYearProvider.Entry

//     private let yearFormatter: DateFormatter = {
//         let formatter = DateFormatter()
//         formatter.dateFormat = "yyyy" // Format to display year without comma
//         return formatter
//     }()

//     var body: some View {
//         let monthInitials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
//         let lightGray = Color(UIColor.systemGray5) // Lighter gray color
//         let currentDate = Date()

//         GeometryReader { geometry in
//             let itemSize: CGFloat = 20 // Fixed size for each square
//             let columnCount = 12
//             let totalItemWidth = itemSize * CGFloat(columnCount)
//             let totalSpacing = geometry.size.width - totalItemWidth
//             let spacing = totalSpacing / CGFloat(columnCount - 1)

//             VStack {
//                 // Text("\(currentDate, formatter: yearFormatter)") // Use date formatter for year
//                 //     .font(.caption2)
//                 //     .fontWeight(.semibold)
                
//                 Spacer()
//                 // Month initials header
//                 LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemSize), spacing: spacing), count: columnCount), spacing: spacing) {
//                     ForEach(Array(monthInitials.enumerated()), id: \.offset) { index, initial in
//                         Text(initial)
//                             .foregroundColor(.gray)
//                             .font(.system(size: 8))
//                             .font(.caption).fontWeight(.semibold)
//                             .frame(maxWidth: .infinity)
//                             .padding(.bottom, 0)
//                     }
//                 }

//                 // Adjusted grid layout
//                 LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemSize), spacing: spacing), count: columnCount), spacing: spacing) {
//                     ForEach(0..<48, id: \.self) { index in // Use a constant integer literal for the range
//                         let month = index % 12
//                         let quarter = index / 12
//                         let startOfMonth = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: month + 1, day: 1))!
//                         let startOfQuarter = Calendar.current.date(byAdding: .day, value: quarter * 7, to: startOfMonth)!

//                         let hasEvent = entry.events.contains { event in
//                             let eventDate = event.date
//                             return eventDate >= startOfQuarter && eventDate < Calendar.current.date(byAdding: .day, value: 7, to: startOfQuarter)!
//                         }

//                         let isCurrentDate = currentDate >= startOfQuarter && currentDate < Calendar.current.date(byAdding: .day, value: 7, to: startOfQuarter)!

//                         Rectangle()
//                             .fill(hasEvent ? Color.blue : lightGray) // Use lighter gray color
//                             .frame(width: itemSize, height: itemSize) // Fixed size for each square
//                             .cornerRadius(4) // Added corner radius
//                             .overlay(
//                                 RoundedRectangle(cornerRadius: 4)
//                                     .stroke(isCurrentDate ? Color.black.opacity(0.3) : Color.clear, lineWidth: 1)
//                             )
//                     }
//                 }
//             }
//         }
//     }
// }

// extension Int {
//     func optionalBounded(by range: Range<Int>) -> Int? {
//         return range.contains(self) ? self : nil
//     }
// }

// struct ThisYearWidget: Widget {
//     let kind: String = "ThisYearWidget"

//     var body: some WidgetConfiguration {
//         StaticConfiguration(kind: kind, provider: ThisYearProvider()) { entry in
//             ThisYearWidgetEntryView(entry: entry)
//         }
//         .configurationDisplayName("This Year")
//         .description("A grid representing your availability for this year.")
//         .supportedFamilies([.systemMedium]) // Updated to support medium size
//     }
// }

// New Upcoming Quarter Widget
// struct UpcomingQuarterProvider: TimelineProvider {
//     func placeholder(in context: Context) -> UpcomingQuarterEntry {
//         UpcomingQuarterEntry(date: Date(), events: [])
//     }

//     func getSnapshot(in context: Context, completion: @escaping (UpcomingQuarterEntry) -> ()) {
//         let entry = UpcomingQuarterEntry(date: Date(), events: [])
//         completion(entry)
//     }
//     func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingQuarterEntry>) -> ()) {
//         var entries: [UpcomingQuarterEntry] = []

//         // Fetch events from UserDefaults or your data source
//         let events = loadEvents()
//         let entry = UpcomingQuarterEntry(date: Date(), events: events)
//         entries.append(entry)

//         let timeline = Timeline(entries: entries, policy: .atEnd)
//         completion(timeline)
//     }

//     private func loadEvents() -> [Event] {
//         let decoder = JSONDecoder()
//         decoder.dateDecodingStrategy = .iso8601
//         if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
//            let data = sharedDefaults.data(forKey: "events"),
//            let decoded = try? decoder.decode([Event].self, from: data) {
//             return decoded
//         } else {
//             return []
//         }
//     }
// }

// struct UpcomingQuarterEntry: TimelineEntry {
//     let date: Date
//     let events: [Event]
// }

// struct UpcomingQuarterWidgetEntryView : View {
//     var entry: UpcomingQuarterProvider.Entry

//     private let weekFormatter: DateFormatter = {
//         let formatter = DateFormatter()
//         formatter.dateFormat = "EEE, MMM d"
//         return formatter
//     }()

//     var body: some View {
//         let currentDate = Date()
//         let daysOfWeek = ["M", "T", "W", "T", "F", "S", "S"]
//         let monthFormatter: DateFormatter = {
//             let formatter = DateFormatter()
//             formatter.dateFormat = "MMM"
//             return formatter
//         }()

//         GeometryReader { geometry in
//             let spacing: CGFloat = 1
//             let columnCount = 17

//             VStack(alignment: .leading) {
//                 // Row for the title of the month
//                 HStack(spacing: spacing) {
//                     Spacer().frame(width: 16) // Empty space for the days of the week column
//                     ForEach(0..<columnCount) { weekOffset in
//                         let startOfWeek = Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: Calendar.current.startOfWeek(for: currentDate, startingOn: .monday))!
//                         let day = Calendar.current.component(.day, from: startOfWeek)
//                         if day <= 7 { // Show month only if the week contains the 1st of the month
//                             Text(monthFormatter.string(from: startOfWeek))
//                                 .font(.system(size: 8, weight: .regular, design: .default))
//                                 .foregroundColor(.gray)
//                                 .frame(width: 16, height: 4) // Set fixed width and height
//                         } else {
//                             Spacer().frame(width: 16, height: 4)
//                         }
//                     }
//                 }

//                 HStack(alignment: .top) {
//                     // Column for days of the week
//                     VStack(spacing: spacing) {
//                         ForEach(daysOfWeek, id: \.self) { day in
//                             Text(day)
//                                 .font(.system(size: 8, weight: .regular, design: .default)) // Corrected argument labels
//                                 .foregroundColor(.gray)
//                                 .frame(height: 16) // Set fixed height to match grid cells
//                         }
//                     }

//                     // Adjusted grid layout
//                     LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: spacing), count: columnCount), spacing: spacing) {
//                         ForEach(0..<columnCount * 7, id: \.self) { index in // Use a constant integer literal for the range
//                             let weekOffset = index % columnCount
//                             let dayOfWeek = index / columnCount
//                             let startOfWeek = Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: Calendar.current.startOfWeek(for: currentDate, startingOn: .monday))!
//                             let date = Calendar.current.date(byAdding: .day, value: dayOfWeek, to: startOfWeek)!

//                             let hasEvent = entry.events.contains { event in
//                                 let eventDate = event.date
//                                 return Calendar.current.isDate(eventDate, inSameDayAs: date)
//                             }

//                             let isCurrentDate = Calendar.current.isDate(currentDate, inSameDayAs: date)

//                             ZStack {
//                                 Rectangle()
//                                     .fill(hasEvent ? Color.blue : Color.clear) // Remove gray background
//                                     .frame(width: 16, height: 16) // Set fixed width and height
//                                     .cornerRadius(20) // Added corner radius
//                                     .overlay(
//                                         RoundedRectangle(cornerRadius: 20)
//                                             .stroke(isCurrentDate ? Color.black.opacity(0.3) : Color.clear, lineWidth: 1)
//                                     )
//                                 Text("\(Calendar.current.component(.day, from: date))")
//                                     .font(.system(size: 8))
//                                     .foregroundColor(hasEvent ? .white : Color.primary) // Make font white if square is blue, otherwise adapt to color scheme
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }

// struct UpcomingQuarterWidget: Widget {
//     let kind: String = "UpcomingQuarterWidget"

//     var body: some WidgetConfiguration {
//         StaticConfiguration(kind: kind, provider: UpcomingQuarterProvider()) { entry in
//             UpcomingQuarterWidgetEntryView(entry: entry)
//         }
//         .configurationDisplayName("This Quarter")
//         .description("A grid representing your availability for the upcoming quarter.")
//         .supportedFamilies([.systemMedium]) // Supports medium size
//     }
// }

// // Helper extension to get the start of the week starting on a specific day
// extension Calendar {
//     func startOfWeek(for date: Date, startingOn weekday: Weekday) -> Date {
//         var components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
//         components.weekday = weekday.rawValue
//         return self.date(from: components)!
//     }
// }

// enum Weekday: Int {
//     case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
// }


