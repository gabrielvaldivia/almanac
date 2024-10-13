import SwiftUI

struct CategoryForm: View {
    @EnvironmentObject var appData: AppData
    @Binding var showingSheet: Bool
    @State private var categoryName: String
    @State private var categoryColor: Color
    @State private var showColorPickerSheet = false
    @State private var repeatOption: RepeatOption
    @State private var showRepeatOptions: Bool
    @State private var customRepeatCount: Int
    @State private var repeatUnit: String
    @State private var repeatUntilOption: RepeatUntilOption
    @State private var repeatUntilCount: Int
    @State private var repeatUntil: Date
    
    var isEditing: Bool
    var onSave: ((name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int, repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int, repeatUntil: Date)) -> Void

    init(showingSheet: Binding<Bool>, isEditing: Bool = false, editingCategory: (name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int, repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int, repeatUntil: Date)? = nil, onSave: @escaping ((name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int, repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int, repeatUntil: Date)) -> Void) {
        self._showingSheet = showingSheet
        self.isEditing = isEditing
        self.onSave = onSave
        
        if let category = editingCategory {
            _categoryName = State(initialValue: category.name)
            _categoryColor = State(initialValue: category.color)
            _repeatOption = State(initialValue: category.repeatOption)
            _showRepeatOptions = State(initialValue: category.repeatOption != .never)
            _customRepeatCount = State(initialValue: category.customRepeatCount)
            _repeatUnit = State(initialValue: category.repeatUnit)
            _repeatUntilOption = State(initialValue: category.repeatUntilOption)
            _repeatUntilCount = State(initialValue: category.repeatUntilCount)
            _repeatUntil = State(initialValue: category.repeatUntil)
        } else {
            _categoryName = State(initialValue: "")
            _categoryColor = State(initialValue: CustomColorPickerSheet.predefinedColors.randomElement() ?? .blue)
            _repeatOption = State(initialValue: .never)
            _showRepeatOptions = State(initialValue: false)
            _customRepeatCount = State(initialValue: 1)
            _repeatUnit = State(initialValue: "Days")
            _repeatUntilOption = State(initialValue: .indefinitely)
            _repeatUntilCount = State(initialValue: 1)
            _repeatUntil = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category Name", text: $categoryName)
                    
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(categoryColor)
                            .frame(width: 29, height: 29)
                            .onTapGesture {
                                showColorPickerSheet = true
                            }
                    }
                }
                
                Section(header: Text("Repeat Options")) {
                    Picker("Repeat", selection: $repeatOption) {
                        ForEach(RepeatOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    if repeatOption != .never {
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
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave((
                            name: categoryName,
                            color: categoryColor,
                            repeatOption: repeatOption,
                            customRepeatCount: customRepeatCount,
                            repeatUnit: repeatUnit,
                            repeatUntilOption: repeatUntilOption,
                            repeatUntilCount: repeatUntilCount,
                            repeatUntil: repeatUntil
                        ))
                        showingSheet = false
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showColorPickerSheet) {
            CustomColorPickerSheet(selectedColor: Binding(
                get: { CodableColor(color: categoryColor) },
                set: { categoryColor = $0.color }
            ), showColorPickerSheet: $showColorPickerSheet)
        }
        .onAppear {
            if isEditing {
                repeatOption = appData.categories.first(where: { $0.name == categoryName })?.repeatOption ?? .never
                showRepeatOptions = repeatOption != .never
                customRepeatCount = appData.categories.first(where: { $0.name == categoryName })?.customRepeatCount ?? 1
                repeatUnit = appData.categories.first(where: { $0.name == categoryName })?.repeatUnit ?? "Days"
                repeatUntilOption = appData.categories.first(where: { $0.name == categoryName })?.repeatUntilOption ?? .indefinitely
                repeatUntilCount = appData.categories.first(where: { $0.name == categoryName })?.repeatUntilCount ?? 1
                repeatUntil = appData.categories.first(where: { $0.name == categoryName })?.repeatUntil ?? Date()
            }
        }
    }
}

