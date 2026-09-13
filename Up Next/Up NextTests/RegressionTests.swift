import XCTest
@testable import Up_Next

final class RegressionTests: XCTestCase {
    func makeEvent(_ title: String = "Event", day: Int = 1, seriesID: UUID? = nil) -> Event {
        let date = Calendar.current.date(from: DateComponents(year: 2030, month: 1, day: day))!
        return Event(title: title, date: date, color: CodableColor(color: .blue),
                     repeatOption: seriesID == nil ? .never : .daily, seriesID: seriesID)
    }

    func testMissingSeriesDoesNotSelectOrDeleteOtherEvents() {
        var converted = makeEvent("Converted")
        converted.repeatOption = .daily
        let unrelated = makeEvent("Unrelated")
        let events = [converted, unrelated]
        XCTAssertTrue(EventSeries.members(of: converted, in: events).isEmpty)
        XCTAssertEqual(EventSeries.removing(converted, from: events).map(\.id), events.map(\.id))
    }

    func testSeriesDeletionPreservesOtherSeriesAndStandaloneEvents() {
        let id = UUID()
        let first = makeEvent(seriesID: id)
        let second = makeEvent(day: 2, seriesID: id)
        let unrelated = makeEvent("Unrelated")
        let otherSeries = makeEvent(seriesID: UUID())
        XCTAssertEqual(EventSeries.removing(first, from: [first, unrelated, second, otherSeries]).map(\.id),
                       [unrelated.id, otherSeries.id])
    }
    func testLongSeriesTitleEditsPreserveEveryOccurrence() {
        let id = UUID()
        let start = makeEvent(seriesID: id).date
        let events = (0..<365).map { offset -> Event in
            var event = makeEvent(seriesID: id)
            event.date = Calendar.current.date(byAdding: .day, value: offset, to: start)!
            return event
        }
        for index in [0, 180, 364] {
            var replacement = events[index]
            replacement.title = "Renamed"
            let updated = EventSeries.updating(events[index], with: replacement, in: events)
            XCTAssertEqual(updated.map(\.id), events.map(\.id))
            XCTAssertEqual(updated.map(\.date), events.map(\.date))
            XCTAssertTrue(updated.allSatisfy { $0.title == "Renamed" })
        }
    }

    func testInterleavedSeriesDoesNotUseUnrelatedNeighborDate() {
        let id = UUID()
        let first = makeEvent(seriesID: id)
        let second = makeEvent(day: 2, seriesID: id)
        let unrelated = makeEvent("Other", day: 20)
        var replacement = first
        replacement.repeatOption = .weekly
        let result = EventSeries.updating(first, with: replacement, in: [first, unrelated, second])
        XCTAssertEqual(result[1].date, unrelated.date)
        XCTAssertEqual(result[2].date, Calendar.current.date(byAdding: .day, value: 7, to: first.date))
    }
}
