import SwiftUI

/// Calendar-day selection keeps the range ordered, including across DST changes.
struct CalendarDateSelection {
    enum Endpoint: Hashable { case start, end }

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
        end = enabled ? (end ?? calendar.date(byAdding: .day, value: 1, to: start) ?? start) : nil
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
        } else if day < start {
            // An earlier tap starts a new range and waits for its end.
            start = day
            end = day
        } else {
            end = day
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    if selection.end != nil {
                        endpointControl
                    }
                    if dynamicTypeSize.isAccessibilitySize { rangeButton }
                    calendar
                    if !dynamicTypeSize.isAccessibilitySize { rangeButton }
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
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(selection.end == nil ? 560 : 620), .large])
        .presentationDragIndicator(.visible)
    }

    private var endpointControl: some View {
        Picker("Editing date", selection: Binding(
            get: { selection.endpoint },
            set: { endpoint in
                selection.endpoint = endpoint
                showMonth(containing: endpoint == .start ? selection.start : selection.end ?? selection.start)
            }
        )) {
            Text("Start").tag(CalendarDateSelection.Endpoint.start)
            Text("End").tag(CalendarDateSelection.Endpoint.end)
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityValue((selection.endpoint == .start ? selection.start : selection.end ?? selection.start)
            .formatted(date: .complete, time: .omitted))
        .accessibilityHint("Choose which date to edit in the calendar.")
        .accessibilityIdentifier("calendarEndpoint")
    }

    private var rangeButton: some View {
        let hasEndDate = selection.end != nil
        return Button {
            selection.setRangeEnabled(!hasEndDate)
            showMonth(containing: selection.end ?? selection.start)
        } label: {
            Text(hasEndDate ? "Remove end date" : "Add end date")
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
        .accessibilityHint(hasEndDate ? "Keep only the start date." : "Add the following day and choose an end date.")
        .accessibilityIdentifier(hasEndDate ? "calendarRemoveEndDate" : "calendarAddEndDate")
    }

    private var calendar: some View {
        VStack(spacing: 8) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
            headerLayout {
                Text(visibleMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .accessibilityIdentifier("calendarMonth")
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack {
                    monthButton(-1, label: "Previous month", icon: "chevron.backward")
                    monthButton(1, label: "Next month", icon: "chevron.forward")
                }
            }

            if !dynamicTypeSize.isAccessibilitySize {
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
            }

            let days = selection.monthDays(containing: visibleMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: dynamicTypeSize.isAccessibilitySize ? 1 : 7), spacing: 4) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        dayButton(date)
                    } else if !dynamicTypeSize.isAccessibilitySize {
                        Color.clear.frame(height: dayHeight).accessibilityHidden(true)
                    }
                }
            }
            .accessibilityIdentifier("dateRangeCalendar")
        }
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
        let selectionColor = EventRowColors.readable(CodableColor(color: .blue), over: CodableColor(color: .white)).color
        return Button {
            selection.select(date)
        } label: {
            Text(date, format: dynamicTypeSize.isAccessibilitySize
                 ? .dateTime.weekday(.abbreviated).month(.abbreviated).day() : .dateTime.day())
                .font(.body.weight(isEndpoint ? .semibold : .regular))
                .foregroundStyle(isEndpoint ? Color.white : selection.calendar.isDateInToday(date) ? .blue : .primary)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: dayHeight)
                .background {
                    ZStack {
                        if isSelected && spansDays {
                            GeometryReader { geometry in
                                Rectangle().fill(.blue.opacity(0.18))
                                    .padding(.leading, isStart && !dynamicTypeSize.isAccessibilitySize ? geometry.size.width / 2 : 0)
                                    .padding(.trailing, isEnd && !dynamicTypeSize.isAccessibilitySize ? geometry.size.width / 2 : 0)
                                    .padding(.vertical, 2)
                            }
                        }
                        if isEndpoint {
                            // Keep the range band from tinting half of the endpoint over the sheet material.
                            if dynamicTypeSize.isAccessibilitySize {
                                RoundedRectangle(cornerRadius: 12).fill(selectionColor)
                            } else {
                                Circle().fill(selectionColor)
                                    .background(Circle().fill(Color(uiColor: .systemBackground)))
                                    .padding(2)
                            }
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
