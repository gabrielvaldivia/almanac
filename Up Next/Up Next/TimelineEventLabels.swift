import UIKit

struct TimelineLabelItem {
    let id: UUID
    let marker: CGRect
    let size: CGSize
}

struct TimelineLabelPlacement {
    let id: UUID
    let marker: CGRect
    let frame: CGRect
    let connector: [CGPoint]
}

/// Place the title and its centered connection together. Reserve both so later
/// titles cannot cover a connector, and never route a line around another label.
enum TimelineEventLabelLayout {
    static let gap: CGFloat = 16

    static func make(items: [TimelineLabelItem], horizontalBounds: ClosedRange<CGFloat>, minimumY: CGFloat = 0,
                     previous: [UUID: CGRect] = [:]) -> [TimelineLabelPlacement] {
        var markers = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.marker) })
        var result: [TimelineLabelPlacement] = []
        for item in items.sorted(by: {
            if $0.marker.minX != $1.marker.minX { return $0.marker.minX < $1.marker.minX }
            if $0.marker.minY != $1.marker.minY { return $0.marker.minY < $1.marker.minY }
            return $0.id.uuidString < $1.id.uuidString
        }) {
            var marker = item.marker
            let size = item.size
            func clampedX(_ x: CGFloat) -> CGFloat {
                max(horizontalBounds.lowerBound, min(x, horizontalBounds.upperBound - size.width))
            }
            let right = CGRect(x: marker.maxX + 6, y: marker.midY - size.height / 2,
                               width: size.width, height: size.height)
            let otherMarkers = markers.filter { $0.key != item.id }.map(\.value)
            let labels = result.map(\.frame)
            let existingLines = result.flatMap { placement in
                Array(zip(placement.connector, placement.connector.dropFirst()))
            }
            func connection(to frame: CGRect) -> [CGPoint]? {
                if frame == right { return [] }
                return centeredConnection(marker: marker, label: frame)
            }
            func isFree(_ frame: CGRect) -> Bool {
                guard frame.minX >= horizontalBounds.lowerBound, frame.maxX <= horizontalBounds.upperBound,
                      frame.minY >= minimumY, frame.size == size,
                      !(Array(markers.values) + labels).contains(where: {
                          $0.insetBy(dx: -4, dy: -4).intersects(frame)
                      }),
                      !existingLines.contains(where: { segment($0.0, $0.1, intersects: frame.insetBy(dx: -4, dy: -4)) })
                else { return false }
                guard let points = connection(to: frame) else { return false }
                return zip(points, points.dropFirst()).allSatisfy { start, end in
                    !(otherMarkers + labels).contains {
                        segment(start, end, intersects: $0.insetBy(dx: -4, dy: -4))
                    } && !existingLines.contains {
                        segmentsCross(start, end, $0.0, $0.1)
                    }
                }
            }
            var candidates = [right]
            let columns = [marker.midX - size.width / 2, marker.minX, marker.maxX - size.width].map(clampedX)
            for distance: CGFloat in [gap, gap + size.height + gap, gap + (size.height + gap) * 2] {
                // Try both sides of the timeline before moving farther away.
                for y in [marker.minY - distance - size.height, marker.maxY + distance] {
                    for x in columns { candidates.append(CGRect(origin: CGPoint(x: x, y: y), size: size)) }
                }
            }
            if let old = previous[item.id], old.size == size {
                let retained = CGRect(x: clampedX(old.minX), y: old.minY, width: old.width, height: old.height)
                // Preserve nearby placements while panning, but don't retain the
                // long, tangled connections produced by a denser earlier scale.
                if abs(retained.midY - marker.midY) <= size.height * 2 + gap * 3 {
                    candidates.insert(retained, at: 0)
                }
            }
            let frame: CGRect
            if let available = candidates.first(where: isFree) {
                frame = available
            } else {
                // A fully surrounded dot cannot have a clear centered leader.
                // Keep its date (x) fixed and separate this event into a new row.
                let rowTop = max(minimumY, markers.values.map(\.maxY).max() ?? minimumY,
                                 labels.map(\.maxY).max() ?? minimumY) + gap * 2
                frame = CGRect(x: clampedX(marker.midX - size.width / 2), y: rowTop,
                               width: size.width, height: size.height)
                marker.origin.y = frame.maxY + gap
                markers[item.id] = marker
            }
            result.append(TimelineLabelPlacement(id: item.id, marker: marker, frame: frame, connector: connection(to: frame) ?? []))
        }
        return result
    }

    private static func centeredConnection(marker: CGRect, label: CGRect) -> [CGPoint]? {
        let start: CGPoint
        let end: CGPoint
        if label.maxY <= marker.minY {
            start = CGPoint(x: marker.midX, y: marker.minY - 2)
            end = CGPoint(x: label.midX, y: label.maxY + 2)
        } else if label.minY >= marker.maxY {
            start = CGPoint(x: marker.midX, y: marker.maxY + 2)
            end = CGPoint(x: label.midX, y: label.minY - 2)
        } else {
            // Side-by-side titles need no leader. Displaced titles belong above
            // or below their dot so both ends can connect vertically.
            return nil
        }
        if abs(start.x - end.x) < 0.0001 { return [start, end] }
        let middleY = (start.y + end.y) / 2
        return [start, CGPoint(x: start.x, y: middleY), CGPoint(x: end.x, y: middleY), end]
    }

    static func roundedConnectorPath(_ points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        guard let first = points.first, let last = points.last, points.count >= 2 else { return path }
        path.move(to: first)
        for index in 1..<(points.count - 1) {
            let previous = points[index - 1], corner = points[index], next = points[index + 1]
            let incoming = hypot(corner.x - previous.x, corner.y - previous.y)
            let outgoing = hypot(next.x - corner.x, next.y - corner.y)
            guard incoming > 0, outgoing > 0 else { continue }
            let radius = min(4, incoming / 2, outgoing / 2)
            let entry = CGPoint(x: corner.x + (previous.x - corner.x) * radius / incoming,
                                y: corner.y + (previous.y - corner.y) * radius / incoming)
            let exit = CGPoint(x: corner.x + (next.x - corner.x) * radius / outgoing,
                               y: corner.y + (next.y - corner.y) * radius / outgoing)
            path.addLine(to: entry)
            path.addQuadCurve(to: exit, controlPoint: corner)
        }
        path.addLine(to: last)
        return path
    }

    static func segment(_ start: CGPoint, _ end: CGPoint, intersects rect: CGRect) -> Bool {
        var lower: CGFloat = 0, upper: CGFloat = 1
        for (origin, delta, minimum, maximum) in [
            (start.x, end.x - start.x, rect.minX, rect.maxX),
            (start.y, end.y - start.y, rect.minY, rect.maxY)
        ] {
            if abs(delta) < 0.0001 {
                if origin < minimum || origin > maximum { return false }
            } else {
                let first = (minimum - origin) / delta, second = (maximum - origin) / delta
                lower = max(lower, min(first, second))
                upper = min(upper, max(first, second))
                if lower > upper { return false }
            }
        }
        return true
    }

    static func segmentsCross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        let dx = b.x - a.x, dy = b.y - a.y
        let ex = d.x - c.x, ey = d.y - c.y
        let determinant = dx * ey - dy * ex
        if abs(determinant) < 0.0001 {
            // Also reserve a little room between parallel connectors.
            let bounds = CGRect(x: min(c.x, d.x), y: min(c.y, d.y),
                                width: max(1, abs(ex)), height: max(1, abs(ey))).insetBy(dx: -2, dy: -2)
            return segment(a, b, intersects: bounds)
        }
        let t = ((c.x - a.x) * ey - (c.y - a.y) * ex) / determinant
        let u = ((c.x - a.x) * dy - (c.y - a.y) * dx) / determinant
        return (0...1).contains(t) && (0...1).contains(u)
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
            line.path = TimelineEventLabelLayout.roundedConnectorPath(placement.connector).cgPath
            line.strokeColor = UIColor(event.color.color).withAlphaComponent(0.65).cgColor
            line.fillColor = nil
            line.lineWidth = 1
            line.lineJoin = .round
            line.lineCap = .round
        }
        return placements.map { max($0.frame.maxY, $0.marker.maxY) }.max() ?? 0
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        alpha > 0.01 && buttons.values.contains { $0.frame.contains(point) }
    }
}
