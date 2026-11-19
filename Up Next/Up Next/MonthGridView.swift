import SwiftUI

/// Splits the main screen at a vertical fold, such as iPhone Duo's inner display
/// opened like a book. Each column gets one side of the fold, so neither the
/// month grid nor the event list spans the hinge.
struct FoldColumns: Equatable {
    static let minimumWidth: CGFloat = 300

    /// Width of the column before the fold, on the left in left-to-right layouts.
    let leading: CGFloat
    /// Width of the column after the fold.
    let trailing: CGFloat
    /// Space the fold takes between the columns.
    let gap: CGFloat

    /// Returns nil unless a vertical fold crosses the content with room for a
    /// column on each side. A horizontal fold (the inner display in portrait),
    /// no fold (the outer display and every other iPhone), and a fold outside
    /// this window (Split View on one side) keep the single-column layout.
    /// Both frames use the same coordinate space.
    init?(content: CGRect, division: CGRect?) {
        guard let division, division.height > division.width else { return nil }
        let leading = division.minX - content.minX
        let trailing = content.maxX - division.maxX
        guard leading >= Self.minimumWidth, trailing >= Self.minimumWidth else { return nil }
        self.leading = leading
        self.trailing = trailing
        gap = division.width
    }
}

/// The width of the months column when the person drags its edge.
enum MonthColumnResize {
    static let minimumMonthsWidth: CGFloat = 280
    static let minimumListWidth: CGFloat = 320
    /// Within this distance, the edge snaps back to the fold.
    static let snapDistance: CGFloat = 24

    /// Keeps both columns usable and snaps to the fold when close to it.
    /// `fold` is the months column's width when its edge is at the fold.
    static func width(proposed: CGFloat, contentWidth: CGFloat, fold: CGFloat) -> CGFloat {
        let upper = max(minimumMonthsWidth, contentWidth - minimumListWidth)
        let clamped = min(upper, max(minimumMonthsWidth, proposed))
        return abs(clamped - fold) <= snapDistance ? fold : clamped
    }
}

enum MonthGrid {
    /// The weeks that show `month`, each with seven days starting on the
    /// calendar's first weekday. Leading and trailing days of the neighboring
    /// months fill the first and last weeks.
    static func weeks(for month: Date, calendar: Calendar = .current) -> [[Date]] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: interval.start) else { return [] }
        var weeks: [[Date]] = []
        var start = firstWeek.start
        while start < interval.end {
            let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            weeks.append(days)
            guard let next = calendar.date(byAdding: .day, value: 7, to: start) else { break }
            start = next
        }
        return weeks
    }

    /// The first day of every month from `first`'s month through `last`'s.
    static func months(from first: Date, through last: Date, calendar: Calendar = .current) -> [Date] {
        guard var month = calendar.dateInterval(of: .month, for: min(first, last))?.start,
              let end = calendar.dateInterval(of: .month, for: max(first, last))?.start else { return [] }
        var months: [Date] = []
        while month <= end {
            months.append(month)
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return months
    }

    /// Events on each day from `first` through `last`, keyed by the start of the
    /// day. Multi-day events appear on every day they cover.
    static func eventsByDay(_ events: [Event], from first: Date, through last: Date,
                            calendar: Calendar = .current) -> [Date: [Event]] {
        let first = calendar.startOfDay(for: first)
        let last = calendar.startOfDay(for: last)
        var result: [Date: [Event]] = [:]
        for event in events {
            let start = calendar.startOfDay(for: event.date)
            let end = max(start, calendar.startOfDay(for: event.endDate ?? event.date))
            guard start <= last, end >= first else { continue }
            var day = max(start, first)
            let lastDay = min(end, last)
            while day <= lastDay {
                result[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return result.mapValues { events in
            events.sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                if $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                return $0.id.uuidString < $1.id.uuidString
            }
        }
    }
}

/// One event's bar within a week: the columns it covers and its lane.
struct MonthGridSegment: Identifiable {
    let event: Event
    let firstColumn: Int
    let lastColumn: Int
    let lane: Int
    /// The event started before the first column, in an earlier week or month.
    let continuesBefore: Bool
    /// The event goes on after the last column.
    let continuesAfter: Bool
    var id: UUID { event.id }

    func covers(_ column: Int) -> Bool { (firstColumn...lastColumn).contains(column) }
}

extension MonthGrid {
    /// One bar per event in a week, so an event across several days is one
    /// continuous bar. `days` has a nil column for each blank day. Longer
    /// events and earlier starts take the lower lanes, and no two bars in a
    /// lane overlap.
    static func segments(for days: [Date?], eventsByDay: [Date: [Event]],
                         calendar: Calendar = .current) -> [MonthGridSegment] {
        var spans: [UUID: (event: Event, first: Int, last: Int)] = [:]
        for (column, day) in days.enumerated() {
            guard let day else { continue }
            for event in eventsByDay[day] ?? [] {
                if let span = spans[event.id] {
                    spans[event.id] = (span.event, span.first, column)
                } else {
                    spans[event.id] = (event, column, column)
                }
            }
        }
        let ordered = spans.values.sorted { a, b in
            if a.first != b.first { return a.first < b.first }
            if a.last - a.first != b.last - b.first { return a.last - a.first > b.last - b.first }
            if a.event.date != b.event.date { return a.event.date < b.event.date }
            if a.event.title != b.event.title {
                return a.event.title.localizedStandardCompare(b.event.title) == .orderedAscending
            }
            return a.event.id.uuidString < b.event.id.uuidString
        }
        var laneEnds: [Int] = []
        return ordered.compactMap { span in
            guard let firstDay = days[span.first], let lastDay = days[span.last] else { return nil }
            let lane = laneEnds.firstIndex { $0 < span.first } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(span.last) } else { laneEnds[lane] = span.last }
            return MonthGridSegment(
                event: span.event, firstColumn: span.first, lastColumn: span.last, lane: lane,
                continuesBefore: calendar.startOfDay(for: span.event.date) < firstDay,
                continuesAfter: calendar.startOfDay(for: span.event.endDate ?? span.event.date) > lastDay)
        }
    }
}

/// Months stacked in a vertical scroll, each day with its events, for the left
/// side of the fold.
struct MonthGridView: View {
    var months: [Date]
    var events: [Event]
    /// Scrolls the month containing the request's date to the top.
    var scrollRequest: EventSheetScrollRequest?
    var bottomInset: CGFloat
    /// The person touched the months to scroll them.
    var onInteraction: () -> Void
    /// The month at the top changed, by scrolling or by a request.
    var onTopMonthChange: (Date) -> Void
    /// The last month came into view.
    var onReachEnd: () -> Void
    /// Shows the tapped day in the event list.
    var onTapDate: (Date) -> Void

    @Environment(\.calendar) private var calendar
    @State private var topMonth: Date?
    @State private var sideInsets = EdgeInsets()

    init(months: [Date], initialMonth: Date, events: [Event],
         scrollRequest: EventSheetScrollRequest?, bottomInset: CGFloat,
         onInteraction: @escaping () -> Void, onTopMonthChange: @escaping (Date) -> Void,
         onReachEnd: @escaping () -> Void, onTapDate: @escaping (Date) -> Void) {
        self.months = months
        self.events = events
        self.scrollRequest = scrollRequest
        self.bottomInset = bottomInset
        self.onInteraction = onInteraction
        self.onTopMonthChange = onTopMonthChange
        self.onReachEnd = onReachEnd
        self.onTapDate = onTapDate
        _topMonth = State(initialValue: initialMonth)
    }

    var body: some View {
        let eventsByDay = months.first.flatMap { first in
            months.last.map { last in
                MonthGrid.eventsByDay(events, from: first,
                                      through: calendar.dateInterval(of: .month, for: last)?.end ?? last,
                                      calendar: calendar)
            }
        } ?? [:]
        VStack(spacing: 0) {
            weekdayHeader
                .padding(.horizontal, 12)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        MonthGridSection(month: month, eventsByDay: eventsByDay,
                                         onTapDate: onTapDate)
                            .onAppear { if month == months.last { onReachEnd() } }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 12)
            }
            .scrollPosition(id: $topMonth, anchor: .top)
            // Beside a side bar or the camera, the scroll view receives the side
            // inset without reaching under it, then pads its content by that
            // much and pushes the months past the column's edge. Reach under
            // the inset, as the event list does, and pad by the same amount.
            .contentMargins(.leading, sideInsets.leading, for: .scrollContent)
            .contentMargins(.trailing, sideInsets.trailing, for: .scrollContent)
            .ignoresSafeArea(.container, edges: .horizontal)
            // Keep the last week clear of the floating filter and add buttons.
            .contentMargins(.bottom, bottomInset, for: .scrollContent)
            .modifier(EventSheetScrollTracking(onInteraction: onInteraction))
            .onChange(of: topMonth) { _, month in
                if let month { onTopMonthChange(month) }
            }
            .onChange(of: scrollRequest) { _, request in
                guard let request, let month = calendar.dateInterval(of: .month, for: request.date)?.start,
                      month != topMonth, months.contains(month) else { return }
                withAnimation(request.animated ? .easeInOut(duration: 0.25) : nil) { topMonth = month }
            }
            .accessibilityIdentifier("monthGrid")
        }
        .onGeometryChange(for: EdgeInsets.self) { proxy in
            proxy.safeAreaInsets
        } action: { insets in
            sideInsets = insets
        }
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        // Each day reads its full date; the weekday letters would repeat it.
        .accessibilityHidden(true)
    }
}

/// One month: its name and its weeks. Days of the neighboring months stay
/// blank, so each day appears once in the stack.
private struct MonthGridSection: View {
    let month: Date
    let eventsByDay: [Date: [Event]]
    let onTapDate: (Date) -> Void

    @Environment(\.calendar) private var calendar
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(TimelineHeading.text(first: month, last: month, calendar: calendar))
                .font(.title3.weight(.bold))
                .padding(.leading, 4)
                .padding(.top, 20)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("monthGridTitle")
            ForEach(MonthGrid.weeks(for: month, calendar: calendar), id: \.first) { week in
                Divider()
                MonthGridWeekRow(
                    days: week.map { calendar.isDate($0, equalTo: month, toGranularity: .month) ? $0 : nil },
                    eventsByDay: eventsByDay, onTapDate: onTapDate
                )
                .frame(height: rowHeight)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A week of days with their events drawn as bars across the days they cover.
private struct MonthGridWeekRow: View {
    let days: [Date?]
    let eventsByDay: [Date: [Event]]
    let onTapDate: (Date) -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .subheadline) private var numberSize: CGFloat = 26
    @ScaledMetric(relativeTo: .caption2) private var barHeight: CGFloat = 16
    private let barSpacing: CGFloat = 2
    private let padding: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / 7
            let segments = MonthGrid.segments(for: days, eventsByDay: eventsByDay, calendar: calendar)
            let available = geometry.size.height - padding * 2 - numberSize - barSpacing
            let capacity = max(0, Int((available + barSpacing) / (barHeight + barSpacing)))
            let showsBars = columnWidth >= 44 && capacity > 0
            // When some bars don't fit, the last lane counts what is hidden.
            let lanes = segments.contains { $0.lane >= capacity } ? capacity - 1 : capacity
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            MonthGridDayCell(
                                date: day, events: eventsByDay[day] ?? [], showsDots: !showsBars,
                                isToday: calendar.isDateInToday(day),
                                onTap: { onTapDate(day) }
                            )
                        } else {
                            Color.clear
                                .accessibilityHidden(true)
                        }
                    }
                }
                if showsBars {
                    ForEach(segments.filter { $0.lane < lanes }) { segment in
                        bar(for: segment, columnWidth: columnWidth)
                    }
                    ForEach(0..<days.count, id: \.self) { column in
                        let hidden = segments.filter { $0.lane >= lanes && $0.covers(column) }.count
                        if hidden > 0 {
                            Text("+\(hidden)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                                .frame(width: columnWidth - padding * 2, height: barHeight, alignment: .leading)
                                .offset(x: CGFloat(column) * columnWidth + padding, y: top(ofLane: lanes))
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func top(ofLane lane: Int) -> CGFloat {
        padding + numberSize + barSpacing + CGFloat(lane) * (barHeight + barSpacing)
    }

    private func bar(for segment: MonthGridSegment, columnWidth: CGFloat) -> some View {
        let dark = colorScheme == .dark
        let colors = EventRowColors(category: segment.event.color, style: "flat", dark: dark, highlighted: false)
        // A bar reaches the cell edge where the event goes on, and keeps a
        // rounded, inset end where it starts or ends.
        let leadingInset = segment.continuesBefore ? 0 : padding
        let trailingInset = segment.continuesAfter ? 0 : padding
        let width = CGFloat(segment.lastColumn - segment.firstColumn + 1) * columnWidth - leadingInset - trailingInset
        let leadingRadius: CGFloat = segment.continuesBefore ? 0 : 4
        let trailingRadius: CGFloat = segment.continuesAfter ? 0 : 4
        return Text(segment.event.title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(colors.title.color)
            .lineLimit(1)
            // Clip long titles at the bar's end instead of ending them in an
            // ellipsis, which leaves almost no title in a one-day bar.
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 4)
            .frame(width: max(0, width), height: barHeight, alignment: .leading)
            .clipped()
            .background(segment.event.color.color.opacity(dark ? 0.3 : 0.18),
                        in: UnevenRoundedRectangle(topLeadingRadius: leadingRadius, bottomLeadingRadius: leadingRadius,
                                                   bottomTrailingRadius: trailingRadius, topTrailingRadius: trailingRadius))
            .offset(x: CGFloat(segment.firstColumn) * columnWidth + leadingInset, y: top(ofLane: segment.lane))
            // Taps on a bar go to the day underneath. Each day's label
            // already names its events.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct MonthGridDayCell: View {
    let date: Date
    let events: [Event]
    /// Days too small for bars show a dot for each event.
    let showsDots: Bool
    let isToday: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var numberSize: CGFloat = 26

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                dayNumber
                if showsDots && !events.isEmpty { dots }
                Spacer(minLength: 0)
            }
            .padding(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Shows this day in the event list")
        .accessibilityIdentifier("monthGridDay")
    }

    private var dayNumber: some View {
        Text(date.formatted(.dateTime.day()))
            .font(.subheadline.weight(isToday ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(isToday ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .frame(minWidth: numberSize, minHeight: numberSize)
            .background {
                if isToday { Circle().fill(.tint) }
            }
    }

    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(events.prefix(3)) { event in
                Circle().fill(event.color.color).frame(width: 6, height: 6)
            }
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if isToday { parts.append("Today") }
        parts.append(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
        if events.isEmpty {
            parts.append("No events")
        } else {
            parts.append(events.count == 1 ? "1 event" : "\(events.count) events")
            parts.append(events.map(\.title).formatted(.list(type: .and)))
        }
        return parts.joined(separator: ", ")
    }
}
