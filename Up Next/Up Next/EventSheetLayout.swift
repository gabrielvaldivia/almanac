import SwiftUI

struct EventSheetScrollRequest: Equatable {
    let id = UUID()
    let date: Date
    var animated = false
}

/// Page future events in calendar days while keeping existing history reachable.
struct EventListWindow {
    private var calendar: Calendar
    private var start: Date
    private(set) var dayCount = 365

    init(today: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        start = calendar.startOfDay(for: today)
    }

    var end: Date { calendar.date(byAdding: .day, value: dayCount, to: start)! }

    func contains(_ date: Date) -> Bool { date < end }

    mutating func loadMore() { dayCount += 365 }

    mutating func refresh(today: Date = Date(), calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: today)
        guard start != today || self.calendar != calendar else { return false }
        self.calendar = calendar
        start = today
        return true
    }

    mutating func include(_ date: Date) {
        guard !contains(date) else { return }
        let offset = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
        dayCount = (offset / 365 + 1) * 365
    }
}

struct EventListTopDates: Equatable {
    var visible: Date?
    var afterResize: Date?
    var requestedHeight: CGFloat?
}

/// Only calendar-date crossings reach the parent, not per-pixel row frames.
/// Check both the visible overlay and its proposed size so shrinking it cannot
/// reveal an earlier row and immediately move the timeline backward again.
struct EventListTopDatesKey: PreferenceKey {
    static var defaultValue = EventListTopDates()
    static func reduce(value: inout EventListTopDates, nextValue: () -> EventListTopDates) {
        let next = nextValue()
        if let date = next.visible { value.visible = value.visible.map { min($0, date) } ?? date }
        if let date = next.afterResize { value.afterResize = value.afterResize.map { min($0, date) } ?? date }
        value.requestedHeight = next.requestedHeight ?? value.requestedHeight
    }
}

enum EventSheetSelection {
    static func nearestDate(to day: CGFloat, anchor: Date, dates: [Date], calendar: Calendar = .current) -> Date? {
        guard !dates.isEmpty else { return nil }
        func offset(_ index: Int) -> CGFloat { CGFloat(calendar.dateComponents([.day], from: anchor, to: dates[index]).day ?? 0) }
        var low = 0, high = dates.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if offset(middle) <= day { low = middle } else { high = middle }
        }
        return dates[abs(offset(low) - day) < abs(offset(high) - day) ? low : high]
    }
}

/// Only the surface the user is controlling may move the other one. Programmatic
/// scroll callbacks can still update the visible date, but cannot echo a request.
struct EventScrollSynchronization {
    enum Source { case timeline, sheet }
    private(set) var source: Source = .timeline
    private var sheetTarget: Date?
    private var timelineTarget: Date?

    mutating func begin(_ source: Source) {
        self.source = source
        sheetTarget = nil
        timelineTarget = nil
    }

    mutating func timelineMoved(to date: Date) -> Bool {
        guard source == .timeline, sheetTarget != date else { return false }
        sheetTarget = date
        return true
    }

    mutating func sheetMoved(to date: Date) -> Bool {
        guard source == .sheet, timelineTarget != date else { return false }
        timelineTarget = date
        return true
    }
}

struct EventSheetScrollTracking: ViewModifier {
    var onInteraction: () -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.onScrollPhaseChange { _, phase in
                // Claim ownership on touch-down, before queued timeline updates
                // can start another programmatic list scroll.
                if phase == .tracking || phase == .interacting { onInteraction() }
            }
        } else {
            content.simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { value in
                if abs(value.translation.height) > abs(value.translation.width) { onInteraction() }
            })
        }
    }
}
