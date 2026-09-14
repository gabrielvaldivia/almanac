import UIKit

struct TimelineLabelItem {
    let id: UUID
    let marker: CGRect
    let size: CGSize
}

struct TimelineLabelPlacement {
    let id: UUID
    let frame: CGRect
    let connector: [CGPoint]
}

/// Titles prefer the space immediately to the right of their marker. A blocked
/// title goes below it, finding the nearest free column before adding more rows.
enum TimelineEventLabelLayout {
    static let gap: CGFloat = 6

    static func make(items: [TimelineLabelItem], horizontalBounds: ClosedRange<CGFloat>, minimumY: CGFloat = 0,
                     previous: [UUID: CGRect] = [:]) -> [TimelineLabelPlacement] {
        let markers = items.map(\.marker)
        var occupied = markers
        var result: [TimelineLabelPlacement] = []
        for item in items.sorted(by: {
            if $0.marker.minX != $1.marker.minX { return $0.marker.minX < $1.marker.minX }
            if $0.marker.minY != $1.marker.minY { return $0.marker.minY < $1.marker.minY }
            return $0.id.uuidString < $1.id.uuidString
        }) {
            let marker = item.marker
            let size = item.size
            func clampedX(_ x: CGFloat) -> CGFloat {
                max(horizontalBounds.lowerBound, min(x, horizontalBounds.upperBound - size.width))
            }
            func collisions(_ frame: CGRect) -> [CGRect] {
                occupied.filter { $0.insetBy(dx: -gap / 2, dy: -gap / 2).intersects(frame) }
            }
            let right = CGRect(x: marker.maxX + gap, y: marker.midY - size.height / 2,
                               width: size.width, height: size.height)
            let frame: CGRect
            let retained = previous[item.id].map {
                CGRect(x: clampedX($0.minX), y: $0.minY, width: $0.width, height: $0.height)
            }
            if let retained, retained.size == size, retained.minY >= minimumY,
               (retained == right || retained.minY >= marker.maxY + gap), collisions(retained).isEmpty {
                frame = retained
            } else if right.minY >= minimumY && right.maxX <= horizontalBounds.upperBound &&
                right.minX >= horizontalBounds.lowerBound && collisions(right).isEmpty {
                frame = right
            } else {
                // Each failed position jumps past an obstacle; dense calendars
                // can extend vertically instead of hiding or overlapping titles.
                let columns = [marker.minX, marker.midX - size.width / 2, marker.maxX - size.width,
                               horizontalBounds.lowerBound, horizontalBounds.upperBound - size.width]
                var candidates: [CGRect] = []
                for x in Set(columns.map(clampedX)) {
                    var candidate = CGRect(x: x, y: max(minimumY, marker.maxY + gap), width: size.width, height: size.height)
                    let blockers = occupied.filter {
                        $0.maxX + gap / 2 > candidate.minX && $0.minX - gap / 2 < candidate.maxX
                    }.sorted { $0.minY < $1.minY }
                    for blocker in blockers {
                        if blocker.maxY + gap / 2 <= candidate.minY { continue }
                        if blocker.minY - gap / 2 >= candidate.maxY { break }
                        candidate.origin.y = blocker.maxY + gap
                    }
                    candidates.append(candidate)
                }
                frame = candidates.min {
                    let first = abs($0.midX - marker.midX) + ($0.minY - marker.maxY) * 2
                    let second = abs($1.midX - marker.midX) + ($1.minY - marker.maxY) * 2
                    return first == second ? $0.minX < $1.minX : first < second
                }!
            }
            let connector: [CGPoint]
            if frame == right { connector = [] }
            else {
                let end = CGPoint(x: max(frame.minX + 4, min(marker.midX, frame.maxX - 4)), y: frame.minY - 2)
                let start = CGPoint(x: marker.midX, y: marker.maxY + 2)
                connector = route(from: start, to: end, marker: marker,
                                  obstacles: occupied.filter { $0 != marker })
            }
            occupied.append(frame)
            result.append(TimelineLabelPlacement(id: item.id, frame: frame, connector: connector))
        }
        return result
    }

    private static func route(from start: CGPoint, to end: CGPoint, marker: CGRect, obstacles: [CGRect]) -> [CGPoint] {
        func clear(_ points: [CGPoint]) -> Bool {
            zip(points, points.dropFirst()).allSatisfy { a, b in
                let segment = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                                     width: max(1, abs(a.x - b.x)), height: max(1, abs(a.y - b.y)))
                return !obstacles.contains { $0.insetBy(dx: -1, dy: -1).intersects(segment) }
            }
        }
        let bendY = start.y + 1
        let direct = [start, CGPoint(x: end.x, y: bendY), end]
        if clear(direct) { return direct }
        // Route around same-day stacks instead of drawing through their dots.
        let columns = [marker.maxX + 3, marker.minX - 3, end.x,
                       (obstacles.map(\.minX).min() ?? marker.minX) - 3,
                       (obstacles.map(\.maxX).max() ?? marker.maxX) + 3]
        for x in Set(columns).sorted(by: {
            let first = abs($0 - start.x), second = abs($1 - start.x)
            return first == second ? $0 < $1 : first < second
        }) {
            let points = [start, CGPoint(x: x, y: bendY), CGPoint(x: x, y: end.y), end]
            if clear(points) { return points }
        }
        return direct
    }
}

/// One overlay keeps text and leader lines separate from the interactive dots.
/// Its empty areas pass through touches so panning and pinching still work.
final class TimelineEventLabelsView: UIView {
    var onSelect: ((UUID) -> Void)?
    private var buttons: [UUID: UIButton] = [:]
    private var lines: [UUID: CAShapeLayer] = [:]
    private var measurements: [UUID: (title: String, font: UIFont, width: CGFloat, size: CGSize)] = [:]
    private var previousMarkers: [UUID: CGRect] = [:]
    private var previousWidth: CGFloat = 0
    private(set) var placements: [TimelineLabelPlacement] = []

    func update(events: [(event: Event, frame: CGRect)], viewport: CGRect, opacity: CGFloat, minimumY: CGFloat) -> CGFloat {
        alpha = opacity
        guard opacity > 0, !events.isEmpty else {
            buttons.values.forEach { $0.removeFromSuperview() }
            lines.values.forEach { $0.removeFromSuperlayer() }
            buttons.removeAll(); lines.removeAll(); measurements.removeAll(); placements = []
            previousMarkers.removeAll()
            return 0
        }
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let maxWidth = max(44, min(180, viewport.width * 0.46))
        let ids = Set(events.map { $0.event.id })
        for id in Array(measurements.keys) where !ids.contains(id) {
            measurements.removeValue(forKey: id)
        }
        let items = events.map { entry in
            let event = entry.event
            let size: CGSize
            if let cached = measurements[event.id], cached.title == event.title,
               cached.font == font, cached.width == maxWidth {
                size = cached.size
            } else {
                let measured = (event.title as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
                size = CGSize(width: max(16, min(maxWidth, ceil(measured.width))), height: max(ceil(font.lineHeight), ceil(measured.height)))
                measurements[event.id] = (event.title, font, maxWidth, size)
            }
            return TimelineLabelItem(id: event.id, marker: entry.frame, size: size)
        }
        let previousFrames = Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0.frame) })
        var retained: [UUID: CGRect] = [:]
        if previousWidth == viewport.width {
            for item in items {
                if let oldMarker = previousMarkers[item.id], let oldFrame = previousFrames[item.id], oldFrame.size == item.size {
                    retained[item.id] = oldFrame.offsetBy(dx: item.marker.minX - oldMarker.minX,
                                                        dy: item.marker.minY - oldMarker.minY)
                }
            }
        }
        placements = TimelineEventLabelLayout.make(items: items, horizontalBounds: (viewport.minX + 8)...(viewport.maxX - 8),
                                                  minimumY: minimumY, previous: retained)
        previousMarkers = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.marker) })
        previousWidth = viewport.width
        let byID = Dictionary(uniqueKeysWithValues: events.map { ($0.event.id, $0.event) })
        let visiblePlacements = placements.filter { $0.frame.intersects(viewport.insetBy(dx: 0, dy: -80)) }
        let visibleIDs = Set(visiblePlacements.map(\.id))
        for id in Array(buttons.keys) where !visibleIDs.contains(id) {
            buttons.removeValue(forKey: id)?.removeFromSuperview()
            lines.removeValue(forKey: id)?.removeFromSuperlayer()
        }
        for placement in visiblePlacements {
            guard let event = byID[placement.id] else { continue }
            let button: UIButton
            if let existing = buttons[event.id] { button = existing }
            else {
                button = UIButton(type: .custom)
                button.addAction(UIAction { [weak self] _ in self?.onSelect?(event.id) }, for: .touchUpInside)
                buttons[event.id] = button
                addSubview(button)
            }
            button.setTitle(event.title, for: .normal)
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = font
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.contentHorizontalAlignment = .left
            button.frame = placement.frame
            button.accessibilityIdentifier = "timelineEventTitle-\(event.id)"
            button.accessibilityLabel = event.title
            button.accessibilityValue = event.date.formatted(date: .abbreviated, time: .omitted)
            button.accessibilityHint = "Show event"
            let line = lines[event.id] ?? CAShapeLayer()
            if lines[event.id] == nil {
                // Match the dot immediately during pans, pinches, and sheet drags.
                line.actions = ["path": NSNull(), "strokeColor": NSNull()]
                lines[event.id] = line
                layer.insertSublayer(line, at: 0)
            }
            let path = UIBezierPath()
            if let first = placement.connector.first {
                path.move(to: first)
                placement.connector.dropFirst().forEach { path.addLine(to: $0) }
            }
            line.path = path.cgPath
            line.strokeColor = UIColor(event.color.color).withAlphaComponent(0.65).cgColor
            line.fillColor = nil
            line.lineWidth = 1
            line.lineJoin = .round
            line.lineCap = .round
        }
        return placements.map(\.frame.maxY).max() ?? 0
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        alpha > 0.01 && buttons.values.contains { $0.frame.contains(point) }
    }
}
