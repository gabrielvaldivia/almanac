import SwiftUI

enum EventSheetSize: String, CaseIterable { case large = "Large", small = "Small" }

struct EventSheetHeights {
    let large: CGFloat
    let small: CGFloat

    init(available: CGFloat, compactTimeline: CGFloat) {
        let available = max(0, available)
        small = min(available, max(200, min(260, available * 0.32)))
        large = max(small, available - min(max(80, compactTimeline), available * 0.25))
    }

    func height(for size: EventSheetSize) -> CGFloat { size == .large ? large : small }
    func clamped(_ height: CGFloat) -> CGFloat { min(large, max(small, height)) }
    func nearest(to height: CGFloat) -> EventSheetSize { height < (large + small) / 2 ? .small : .large }
    func timelineExpansion(at height: CGFloat) -> CGFloat { min(1, max(0, (large - height) / max(1, large - small))) }
}

struct EventSheetDrag {
    let heights: EventSheetHeights
    let startHeight: CGFloat
    var translation: CGFloat = 0
    var height: CGFloat { heights.clamped(startHeight - translation) }
}

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
