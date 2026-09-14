import SwiftUI

struct CategoryForm: View {
    @EnvironmentObject var appData: AppData
    @Binding var showingSheet: Bool
    @State private var categoryName: String
    @State private var keywordsText: String
    @State private var categoryColor: Color
    @State private var showColorPickerSheet = false
    @State private var repeatOption: RepeatOption
    @State private var showRepeatOptions: Bool
    @State private var customRepeatCount: Int
    @State private var repeatUnit: String
    @State private var repeatUntilOption: RepeatUntilOption
    @State private var repeatUntilCount: Int
    @State private var repeatUntil: Date

    private let originalName: String?

    var isEditing: Bool
    var onSave: (EventCategory) -> Void

    init(
        showingSheet: Binding<Bool>, isEditing: Bool = false,
        editingCategory: EventCategory? = nil,
        onSave: @escaping (EventCategory) -> Void
    ) {
        self._showingSheet = showingSheet
        self.originalName = editingCategory?.name
        self.isEditing = isEditing
        self.onSave = onSave

        if let category = editingCategory {
            _keywordsText = State(initialValue: category.keywords.joined(separator: ", "))
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
            _keywordsText = State(initialValue: "")
            _categoryName = State(initialValue: "")
            _categoryColor = State(
                initialValue: CustomColorPickerSheet.predefinedColors.randomElement() ?? .blue)
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
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 0) {
                        TextField("Category Name", text: $categoryName)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .frame(minHeight: 44)

                        if !categoryName.isEmpty && !CategoryName.isValid(categoryName, existing: appData.categories.map(\.name), excluding: originalName) {
                            Text("Choose a unique category name. All Categories is reserved for widget filters.")
                                .font(.footnote).foregroundStyle(.red).padding(.horizontal)
                        }
                        Divider()
                            .padding(.leading)

                        ColorSelectionRow(color: categoryColor) {
                            showColorPickerSheet = true
                        }

                        Divider()
                            .padding(.leading)

                        RepeatOptions(
                            repeatOption: $repeatOption,
                            showRepeatOptions: $showRepeatOptions,
                            customRepeatCount: $customRepeatCount,
                            repeatUnit: $repeatUnit,
                            repeatUntilOption: $repeatUntilOption,
                            repeatUntilCount: $repeatUntilCount,
                            repeatUntil: $repeatUntil
                        )
                        .padding(.vertical, 6)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keywords")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                        ZStack(alignment: .topLeading) {
                            if keywordsText.isEmpty {
                                Text("e.g. book, reading, book club")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $keywordsText)
                                .scrollContentBackground(.hidden)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .accessibilityLabel("Keywords")
                                .accessibilityIdentifier("categoryKeywords")
                        }
                        .frame(height: 96)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        Text("Automatically select this category when any keyword or phrase appears. Separate with commas or new lines.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))

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
                        onSave(
                            (
                                name: categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                                color: categoryColor,
                                repeatOption: repeatOption,
                                customRepeatCount: customRepeatCount,
                                repeatUnit: repeatUnit,
                                repeatUntilOption: repeatUntilOption,
                                repeatUntilCount: repeatUntilCount,
                                repeatUntil: repeatUntil,
                                keywords: CategoryKeywords.parse(keywordsText)
                            ))
                        showingSheet = false
                    }
                    .disabled(appData.categoryStorageError != nil || !CategoryName.isValid(categoryName, existing: appData.categories.map(\.name), excluding: originalName))
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .tint(categoryColor)

        .sheet(isPresented: $showColorPickerSheet) {
            CustomColorPickerSheet(
                selectedColor: Binding(
                    get: { CodableColor(color: categoryColor) },
                    set: { categoryColor = $0.color }
                ), showColorPickerSheet: $showColorPickerSheet)
        }
        .onAppear {
            if isEditing {
                repeatOption =
                    appData.categories.first(where: { $0.name == categoryName })?.repeatOption
                    ?? .never
                showRepeatOptions = repeatOption != .never
                customRepeatCount =
                    appData.categories.first(where: { $0.name == categoryName })?.customRepeatCount
                    ?? 1
                repeatUnit =
                    appData.categories.first(where: { $0.name == categoryName })?.repeatUnit
                    ?? "Days"
                repeatUntilOption =
                    appData.categories.first(where: { $0.name == categoryName })?.repeatUntilOption
                    ?? .indefinitely
                repeatUntilCount =
                    appData.categories.first(where: { $0.name == categoryName })?.repeatUntilCount
                    ?? 1
                repeatUntil =
                    appData.categories.first(where: { $0.name == categoryName })?.repeatUntil
                    ?? Date()
            }
        }
    }
}
