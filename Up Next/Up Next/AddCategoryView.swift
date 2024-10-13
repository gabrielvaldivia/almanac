// //
// //  AddCategoryView.swift
// //  Up Next
// //
// //  Created by Gabriel Valdivia on 7/13/24.
// //

// import SwiftUI

// struct AddCategoryView: View {
//     @EnvironmentObject var appData: AppData
//     @Binding var showingAddCategorySheet: Bool
//     @State private var newCategoryName: String = ""
//     @State private var newCategoryColor: Color
//     @State private var showColorPickerSheet = false
//     @State private var repeatOption: RepeatOption = .never
//     @State private var showRepeatOptions: Bool = false
//     @State private var customRepeatCount: Int = 1
//     @State private var repeatUnit: String = "Days"
//     @State private var repeatUntilOption: RepeatUntilOption = .indefinitely
//     @State private var repeatUntilCount: Int = 1
//     @State private var repeatUntil: Date = Date()
//     var onSave: ((name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int, repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int, repeatUntil: Date)) -> Void
    
//     init(showingAddCategorySheet: Binding<Bool>, onSave: @escaping ((name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int, repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int, repeatUntil: Date)) -> Void) {
//         self._showingAddCategorySheet = showingAddCategorySheet
//         self.onSave = onSave
//         let randomColor = CustomColorPickerSheet.predefinedColors.randomElement() ?? .blue
//         self._newCategoryColor = State(initialValue: randomColor)
//     }

//     var body: some View {
//         ZStack {
//             Color(UIColor.systemGroupedBackground)
//                 .edgesIgnoringSafeArea(.all)
            
//             ScrollView {
//                 CategoryForm(
//                     categoryName: $newCategoryName,
//                     categoryColor: $newCategoryColor,
//                     showColorPickerSheet: $showColorPickerSheet,
//                     repeatOption: $repeatOption,
//                     showRepeatOptions: $showRepeatOptions,
//                     customRepeatCount: $customRepeatCount,
//                     repeatUnit: $repeatUnit,
//                     repeatUntilOption: $repeatUntilOption,
//                     repeatUntilCount: $repeatUntilCount,
//                     repeatUntil: $repeatUntil,
//                     isEditing: false,
//                     saveAction: {
//                         onSave((
//                             name: newCategoryName,
//                             color: newCategoryColor,
//                             repeatOption: repeatOption,
//                             customRepeatCount: customRepeatCount,
//                             repeatUnit: repeatUnit,
//                             repeatUntilOption: repeatUntilOption,
//                             repeatUntilCount: repeatUntilCount,
//                             repeatUntil: repeatUntil
//                         ))
//                         showingAddCategorySheet = false
//                     }
//                 )
//             }
//             .padding()
            
//         }
//         .navigationTitle("Add Category")
//         .navigationBarTitleDisplayMode(.inline)
//         .toolbar {
//             ToolbarItem(placement: .navigationBarLeading) {
//                 Button("Cancel") {
//                     showingAddCategorySheet = false
//                 }
//             }
//             ToolbarItem(placement: .navigationBarTrailing) {
//                 Button("Save") {
//                     onSave((
//                         name: newCategoryName,
//                         color: newCategoryColor,
//                         repeatOption: repeatOption,
//                         customRepeatCount: customRepeatCount,
//                         repeatUnit: repeatUnit,
//                         repeatUntilOption: repeatUntilOption,
//                         repeatUntilCount: repeatUntilCount,
//                         repeatUntil: repeatUntil
//                     ))
//                     showingAddCategorySheet = false
//                 }
//                 .disabled(newCategoryName.isEmpty)
//             }
//         }
//         .sheet(isPresented: $showColorPickerSheet) {
//             CustomColorPickerSheet(selectedColor: Binding(
//                 get: { CodableColor(color: newCategoryColor) },
//                 set: { newCategoryColor = $0.color }
//             ), showColorPickerSheet: $showColorPickerSheet)
//         }
//     }
// }

// extension CodableColor: Equatable {
//     static func == (lhs: CodableColor, rhs: CodableColor) -> Bool {
//         return lhs.color == rhs.color
//     }
// }

// extension Color {
//     var contrastColor: Color {
//         var red: CGFloat = 0
//         var green: CGFloat = 0
//         var blue: CGFloat = 0
//         var opacity: CGFloat = 0
        
//         UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        
//         let brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
//         return brightness > 0.5 ? .black : .white
//     }
// }
