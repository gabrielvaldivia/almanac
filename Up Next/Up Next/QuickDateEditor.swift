import SwiftUI

/// Calendar-day selection keeps the range ordered, including across DST changes.
struct CalendarDateSelection {
    enum Endpoint { case start, end }

    private(set) var start: Date
    private(set) var end: Date?
    var endpoint: Endpoint = .start
    let calendar: Calendar

    init(start: Date, end: Date?, calendar: Calendar = .current) {
        self.calendar = calendar
        let firstDay = calendar.startOfDay(for: start)
        self.start = firstDay
        self.end = end.map { max(firstDay, calendar.startOfDay(for: $0)) }
    }

    mutating func setRangeEnabled(_ enabled: Bool) {
        end = enabled ? (end ?? start) : nil
        endpoint = enabled ? .end : .start
    }

    mutating func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        guard let previousEnd = end else {
            start = day
            return
        }
        if endpoint == .start {
            start = day
            end = max(day, previousEnd)
            endpoint = .end
        } else if day < start {
            // An earlier tap starts a new range and waits for its end.
            start = day
            end = day
        } else {
            end = day
            endpoint = .start
        }
    }

    func contains(_ date: Date) -> Bool {
        (start...(end ?? start)).contains(calendar.startOfDay(for: date))
    }

    func monthDays(containing date: Date) -> [Date?] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let offset = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: offset) + days.map {
            calendar.date(byAdding: .day, value: $0 - 1, to: month.start)
        }
    }
}

struct QuickDateEditor: View {
    @State private var selection: CalendarDateSelection
    @State private var visibleMonth: Date
    var onSave: (Date, Date?) -> Void
    @ScaledMetric(relativeTo: .body) private var dayHeight = 44.0

    init(options: DateOptions, onSave: @escaping (Date, Date?) -> Void) {
        let selection = CalendarDateSelection(start: options.date,
                                             end: options.showEndDate ? options.endDate : nil)
        _selection = State(initialValue: selection)
        _visibleMonth = State(initialValue: selection.calendar.dateInterval(of: .month, for: selection.start)!.start)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Toggle("End date", isOn: Binding(
                        get: { selection.end != nil },
                        set: { enabled in
                            selection.setRangeEnabled(enabled)
                            showMonth(containing: selection.start)
                        }
                    ))
                    .tint(.blue)
                    .padding(.horizontal, 4)

                    HStack(spacing: 8) {
                        endpointButton(.start, title: selection.end == nil ? "Date" : "Start date", date: selection.start)
                        if let end = selection.end {
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            endpointButton(.end, title: "End date", date: end)
                        }
                    }

                    calendar

                    if selection.end != nil {
                        Text(selection.endpoint == .start ? "Choose a start date" : "Choose an end date")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("calendarSelectionHint")
                    }
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("quickDatePicker")
            .navigationTitle("Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(selection.start, selection.end) }
                }
            }
        }
        .presentationDetents([.height(600), .large])
        .presentationDragIndicator(.visible)
    }

    private func endpointButton(_ endpoint: CalendarDateSelection.Endpoint, title: String, date: Date) -> some View {
        Button {
            selection.endpoint = endpoint
            showMonth(containing: date)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selection.endpoint == endpoint ? .blue : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(selection.endpoint == endpoint ? Color.blue.opacity(0.12) : Color(uiColor: .secondarySystemFill),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(endpoint == .start ? "Start date" : "End date")
        .accessibilityValue(date.formatted(date: .abbreviated, time: .omitted))
        .accessibilityAddTraits(selection.endpoint == endpoint ? .isSelected : [])
        .accessibilityIdentifier(endpoint == .start ? "calendarStartDate" : "calendarEndDate")
    }

    private var calendar: some View {
        VStack(spacing: 8) {
            HStack {
                Text(visibleMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .accessibilityIdentifier("calendarMonth")
                Spacer(minLength: 0)
                monthButton(-1, label: "Previous month", icon: "chevron.backward")
                monthButton(1, label: "Next month", icon: "chevron.forward")
            }

            let symbols = selection.calendar.veryShortStandaloneWeekdaySymbols
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(symbols[(index + selection.calendar.firstWeekday - 1) % 7])
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            let days = selection.monthDays(containing: visibleMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: dayHeight).accessibilityHidden(true)
                    }
                }
            }
            .accessibilityIdentifier("dateRangeCalendar")
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func monthButton(_ offset: Int, label: String, icon: String) -> some View {
        Button {
            if let date = selection.calendar.date(byAdding: .month, value: offset, to: visibleMonth) {
                visibleMonth = date
            }
        } label: {
            Image(systemName: icon).font(.body.weight(.semibold)).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
        .accessibilityLabel(label)
    }

    private func dayButton(_ date: Date) -> some View {
        let isStart = date == selection.start
        let isEnd = date == selection.end
        let isEndpoint = isStart || isEnd
        let isSelected = selection.contains(date)
        let spansDays = selection.end.map { $0 > selection.start } ?? false
        return Button {
            selection.select(date)
        } label: {
            Text(date, format: .dateTime.day())
                .font(.body.weight(isEndpoint ? .semibold : .regular))
                .foregroundStyle(isEndpoint ? Color.white : selection.calendar.isDateInToday(date) ? .blue : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: dayHeight)
                .background {
                    ZStack {
                        if isSelected && spansDays {
                            GeometryReader { geometry in
                                Rectangle().fill(.blue.opacity(0.18))
                                    .padding(.leading, isStart ? geometry.size.width / 2 : 0)
                                    .padding(.trailing, isEnd ? geometry.size.width / 2 : 0)
                                    .padding(.vertical, 2)
                            }
                        }
                        if isEndpoint {
                            // Keep the range band from tinting half of the endpoint over the sheet material.
                            Circle().fill(.blue)
                                .background(Circle().fill(Color(uiColor: .systemBackground)))
                                .padding(2)
                        }
                    }
                    .foregroundStyle(Color.blue)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(isStart && isEnd ? "Start and end date" : isStart ? "Start date" : isEnd ? "End date" : isSelected ? "In selected range" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("calendarDay-\(selection.calendar.component(.day, from: date))")
    }

    private func showMonth(containing date: Date) {
        visibleMonth = selection.calendar.dateInterval(of: .month, for: date)!.start
    }
}
