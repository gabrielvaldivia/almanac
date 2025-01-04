import SwiftUI

// Import models from AppData
struct Event: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date
    var endDate: Date?
    var color: CodableColor
    var category: String?
    var notificationsEnabled: Bool = true
    var repeatOption: RepeatOption = .never
    var repeatUntil: Date?
    var seriesID: UUID?
    var customRepeatCount: Int?
    var repeatUnit: String?
    var repeatUntilCount: Int?
    var useCustomRepeatOptions: Bool = false

    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
    }
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(color: Color) {
        // Default to blue if color components can't be extracted
        self.red = 0
        self.green = 0
        self.blue = 1
        self.opacity = 1
    }
}

enum RepeatOption: String, Codable, CaseIterable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
}

class AppData: ObservableObject {
    @Published var events: [Event] = []
}

struct EventTimelineView: View {
    @EnvironmentObject var appData: AppData
    var events: [Event]
    let numberOfDays: Int = 7
    @Environment(\.colorScheme) var colorScheme

    private let dayWidth: CGFloat = 60
    private let eventHeight: CGFloat = 24
    private let maxStaggeredEvents: Int = 3

    private var startDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var dateRange: [Date] {
        (0..<numberOfDays).map { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
        }
    }

    private func eventsForDate(_ date: Date) -> [Event] {
        events.filter { event in
            let eventStart = Calendar.current.startOfDay(for: event.date)
            let eventEnd = event.endDate.map { Calendar.current.startOfDay(for: $0) } ?? eventStart
            let targetDate = Calendar.current.startOfDay(for: date)
            return targetDate >= eventStart && targetDate <= eventEnd
        }
    }

    private func staggeredOffset(for index: Int, totalEvents: Int) -> CGFloat {
        let maxOffset = eventHeight * 0.8
        let step = maxOffset / CGFloat(min(totalEvents, maxStaggeredEvents))
        return step * CGFloat(index)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(dateRange, id: \.self) { date in
                    VStack(alignment: .center, spacing: 4) {
                        // Day of week
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2)
                            .foregroundColor(.gray)

                        // Day number
                        ZStack {
                            if Calendar.current.isDateInToday(date) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 24, height: 24)
                            }
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption.weight(.medium))
                                .foregroundColor(
                                    Calendar.current.isDateInToday(date) ? .white : .primary)
                        }

                        // Events for this day
                        let dayEvents = eventsForDate(date)
                        ZStack(alignment: .top) {
                            ForEach(Array(dayEvents.enumerated()), id: \.element.id) {
                                index, event in
                                EventPill(event: event)
                                    .offset(
                                        y: staggeredOffset(for: index, totalEvents: dayEvents.count)
                                    )
                            }
                        }
                        .frame(height: eventHeight * 2.5)
                        .padding(.top, 4)
                    }
                    .frame(width: dayWidth)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct EventPill: View {
    var event: Event

    var body: some View {
        Text(event.title)
            .lineLimit(1)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(event.color.color.opacity(0.2))
            .foregroundColor(event.color.color)
            .cornerRadius(12)
    }
}
