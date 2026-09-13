import SwiftUI

struct AddEventButton: View {
    @Binding var selectedCategoryFilter: String?
    @Binding var showAddEventSheet: Bool
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var selectedCategory: String?
    @EnvironmentObject var appData: AppData

    var body: some View {
        let buttonColor = self.selectedCategoryFilter != nil ? appData.categories.first(where: { $0.name == self.selectedCategoryFilter })?.color ?? Color.black : appData.categories.first(where: { $0.name == appData.defaultCategory })?.color ?? Color.blue

        Button {
            newEventTitle = ""
            newEventDate = Date()
            newEventEndDate = Date()
            showEndDate = false
            selectedCategory = selectedCategoryFilter ?? (appData.defaultCategory.isEmpty ? nil : appData.defaultCategory)
            showAddEventSheet = true
        } label: {
            Image(systemName: "plus").font(.title.bold()).foregroundStyle(.white)
                .frame(width: 80, height: 60)
                .background(buttonColor, in: Capsule())
                .shadow(color: buttonColor.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(AddEventPressStyle())
        .accessibilityLabel("Add Event")
        .accessibilityIdentifier("addEventButton")
        .disabled(appData.storageError != nil)
    }
}

private struct AddEventPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
