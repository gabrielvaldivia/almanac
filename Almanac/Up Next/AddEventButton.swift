import SwiftUI

struct AddEventButton: View {
    @Binding var selectedCategoryFilter: String?
    @Binding var showAddEventSheet: Bool
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var selectedCategory: String?
    @GestureState private var isButtonPressed: Bool = false
    @EnvironmentObject var appData: AppData

    var body: some View {
        let buttonColor = self.selectedCategoryFilter != nil ? appData.categories.first(where: { $0.name == self.selectedCategoryFilter })?.color ?? Color.black : appData.categories.first(where: { $0.name == appData.defaultCategory })?.color ?? Color.blue

        ZStack {
            RoundedRectangle(cornerRadius: 40)
                .fill(buttonColor)
                .frame(width: 80, height: 60)
                .shadow(color: buttonColor.opacity(0.3), radius: 10, x: 0, y: 5)
                .scaleEffect(isButtonPressed ? 0.7 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: isButtonPressed)

            Image(systemName: "plus")
                .font(.title)
                .bold()
                .foregroundColor(.white)
                .scaleEffect(isButtonPressed ? 0.7 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: isButtonPressed)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isButtonPressed) { _, isPressed, _ in
                    isPressed = true
                }
                .onEnded { _ in
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    self.newEventTitle = ""
                    self.newEventDate = Date()
                    self.newEventEndDate = Date()
                    self.showEndDate = false
                    self.selectedCategory = self.selectedCategoryFilter ?? (appData.defaultCategory.isEmpty ? "Work" : appData.defaultCategory)
                    self.showAddEventSheet = true
                }
        )
    }
}
