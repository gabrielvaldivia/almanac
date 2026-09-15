import Foundation

func generateRepeatingEvents(for event: Event, repeatUntilOption: RepeatUntilOption) -> [Event] {
    if event.repeatOption == .never { return [event] }
    return Recurrence.generate(event, rule: RecurrenceRule(event: event, end: repeatUntilOption))
}
