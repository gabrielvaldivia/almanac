import SwiftUI

struct EventSheetScrollRequest: Equatable {
    let id = UUID()
    let date: Date
    var animated = false
}

struct EventSheetVisibleDay: Equatable {
    let date: Date
    let minY: CGFloat
    let maxY: CGFloat
}

struct EventSheetVisibleDaysKey: PreferenceKey {
    static var defaultValue: [EventSheetVisibleDay] = []
    static func reduce(value: inout [EventSheetVisibleDay], nextValue: () -> [EventSheetVisibleDay]) { value += nextValue() }
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
                if phase == .interacting { onInteraction() }
            }
        } else {
            content.simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { value in
                if abs(value.translation.height) > abs(value.translation.width) { onInteraction() }
            })
        }
    }
}
