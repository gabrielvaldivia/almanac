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
}
