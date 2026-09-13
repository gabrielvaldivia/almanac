import SwiftUI

struct QuickAddEventField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var onSubmit: () -> Void

    var body: some View {
        TextField("Add an event, like Dune 12/18", text: $text)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .focused($isFocused)
            .accessibilityLabel("Quick event entry")
            .accessibilityHint("Enter an event title and date, then submit to add it.")
            .accessibilityIdentifier("quickEventInput")
            .onSubmit(onSubmit)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .modifier(FloatingControlSurface())
    }
}

struct FloatingControlSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}
