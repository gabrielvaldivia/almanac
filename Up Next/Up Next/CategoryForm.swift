import SwiftUI

struct CategoryForm: View {
    @Binding var categoryName: String
    @Binding var categoryColor: Color
    @Binding var showColorPickerSheet: Bool
    @Binding var repeatOption: RepeatOption
    @Binding var showRepeatOptions: Bool
    @Binding var customRepeatCount: Int
    @Binding var repeatUnit: String
    @Binding var repeatUntilOption: RepeatUntilOption
    @Binding var repeatUntilCount: Int
    @Binding var repeatUntil: Date
    @FocusState private var isCategoryNameFieldFocused: Bool
    var isEditing: Bool
    var saveAction: () -> Void
    
    var body: some View {
        Form {
            TextField("Category Name", text: $categoryName)
                .focused($isCategoryNameFieldFocused)
            HStack {
                Text("Color")
                Spacer()
                Button(action: {
                    showColorPickerSheet = true
                }) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 24, height: 24)
                }
            }
            
            RepeatOptions(
                repeatOption: $repeatOption,
                showRepeatOptions: $showRepeatOptions,
                customRepeatCount: $customRepeatCount,
                repeatUnit: $repeatUnit,
                repeatUntilOption: $repeatUntilOption,
                repeatUntilCount: $repeatUntilCount,
                repeatUntil: $repeatUntil
            )
        }
        
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCategoryNameFieldFocused = true
            }
        }
    }
}
