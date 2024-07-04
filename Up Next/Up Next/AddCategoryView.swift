import SwiftUI

struct AddCategoryView: View {
    @Binding var newCategoryName: String
    @Binding var newCategoryColor: Color
    @FocusState var isCategoryNameFieldFocused: Bool
    @Binding var showingAddCategorySheet: Bool
    var appData: AppData

    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $newCategoryName)
                    .focused($isCategoryNameFieldFocused)
                ColorPicker("Choose Color", selection: $newCategoryColor)
            }
            .formStyle(GroupedFormStyle())
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingAddCategorySheet = false
                },
                trailing: Button("Save") {
                    let newCategory = (name: newCategoryName, color: newCategoryColor)
                    appData.categories.append(newCategory)
                    showingAddCategorySheet = false
                }
            )
        }
        .onAppear {
            isCategoryNameFieldFocused = true
        }
    }
}
