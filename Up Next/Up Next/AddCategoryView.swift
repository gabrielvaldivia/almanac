import SwiftUI

struct AddCategoryView: View {
    @Binding var newCategoryName: String
    @Binding var newCategoryColor: Color
    @Binding var showingAddCategorySheet: Bool
    var appData: AppData
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isCategoryNameFieldFocused: Bool // Use FocusState here

    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $newCategoryName)
                    .focused($isCategoryNameFieldFocused) // Use focused modifier
                ColorPicker("Choose Color", selection: $newCategoryColor)
            }
            .formStyle(GroupedFormStyle())
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingAddCategorySheet = false
                    presentationMode.wrappedValue.dismiss() // Dismiss the sheet
                },
                trailing: Button("Save") {
                    let newCategory = (name: newCategoryName, color: newCategoryColor)
                    appData.categories.append(newCategory)
                    showingAddCategorySheet = false
                    presentationMode.wrappedValue.dismiss() // Dismiss the sheet
                }
            )
        }
        .onAppear {
            isCategoryNameFieldFocused = true
        }
    }
}
