import SwiftUI

struct QuickAddEventField: View {
    @Binding var text: String
    var color: Color
    var onAdd: (ParsedEventInput) -> Void
    var onOpenDetails: (ParsedEventInput?) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        let parsed = QuickEventParser.parse(text)
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        HStack(spacing: 4) {
            Button(action: openDetails) {
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Edit event details")
            .accessibilityHint("Opens the full event form with your title and date.")
            .accessibilityIdentifier("manualEventInput")
            .padding(.leading, 4)

            TextField("Add an event, like Dune 12/18", text: $text)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($isFocused)
                .accessibilityLabel("Quick event entry")
                .accessibilityHint("Enter an event title followed by a date, then tap Done to add.")
                .accessibilityIdentifier("quickEventInput")
                .onSubmit {
                    submit()
                }
                .padding(.vertical, 14)
                .padding(.trailing, hasText ? 0 : 18)

            if hasText {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(parsed.map(submitLabel) ?? "Continue to event details")
                .accessibilityIdentifier("quickAddSubmit")
                .padding(.trailing, 4)
            }
        }
        .tint(color)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func submit() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let parsed = QuickEventParser.parse(text) {
            add(parsed)
        } else {
            openDetails()
        }
    }

    private func submitLabel(_ input: ParsedEventInput) -> String {
        let date = input.date.formatted(date: .complete, time: .omitted)
        guard let recurrence = input.recurrence else { return "Add \(input.title) on \(date)" }
        var label = "Add \(input.title), repeating every \(recurrence.interval) \(recurrence.unit.lowercased()), starting \(date)"
        if let until = recurrence.until {
            label += ", until \(until.formatted(date: .complete, time: .omitted))"
        }
        return label
    }

    private func add(_ parsed: ParsedEventInput) {
        onAdd(parsed)
        isFocused = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func openDetails() {
        isFocused = false
        onOpenDetails(QuickEventParser.parse(text))
    }
}
