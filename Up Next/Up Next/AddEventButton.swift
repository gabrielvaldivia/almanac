import SwiftUI

struct QuickAddEventField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @Binding var overrides: QuickEventOverrides
    var draft: NewEventDraft
    var categories: [(name: String, color: Color)]
    var onSubmit: () -> Void
    var onEdit: () -> Void

    @State private var showingDatePicker = false
    @State private var pickerDate = Date()
    @State private var showingRepeatPicker = false
    @State private var repeatDraft: DateOptions?

    private var dateLabel: String {
        let calendar = Calendar.current
        let date = draft.dateOptions.date
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.component(.year, from: date) != calendar.component(.year, from: Date()) {
            return date.formatted(.dateTime.month(.abbreviated).day().year(.twoDigits))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var repeatLabel: String {
        let options = draft.dateOptions
        if options.repeatOption == .custom {
            return "Every \(options.customRepeatCount) \(options.repeatUnit.lowercased())"
        }
        return options.repeatOption.rawValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Add an event, like Dune 12/18", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .focused($isFocused)
                .accessibilityLabel("Quick event entry")
                .accessibilityHint("Type an event. The date, category and repeat buttons update as you type.")
                .accessibilityIdentifier("quickEventInput")
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)

            HStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        dateMenu
                        categoryMenu
                        repeatMenu
                        Button(action: onEdit) { pill("Edit") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit event details")
                            .accessibilityIdentifier("manualEventInput")
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(draft.categoryOptions.selectedColor.color, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                .accessibilityLabel("Submit event")
                .accessibilityHint("Adds the event using the values shown in the composer.")
                .accessibilityIdentifier("quickAddSubmit")
            }
        }
        .padding(8)
        .modifier(FloatingControlSurface())
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                DatePicker("Event date", selection: $pickerDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accessibilityIdentifier("quickDatePicker")
                    .padding()
                    .navigationTitle("Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                overrides.date = Calendar.current.startOfDay(for: pickerDate)
                                showingDatePicker = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingRepeatPicker) {
            if let repeatDraft {
                QuickRepeatEditor(options: repeatDraft) {
                    overrides.repeatOptions = $0
                    showingRepeatPicker = false
                }
            }
        }
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemFill), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private var dateMenu: some View {
        Menu {
            Button("Today") { overrides.date = Calendar.current.startOfDay(for: Date()) }
            Button("Tomorrow") {
                overrides.date = Calendar.current.date(byAdding: .day, value: 1,
                                                        to: Calendar.current.startOfDay(for: Date()))
            }
            Button("Choose Date…") {
                isFocused = false
                pickerDate = draft.dateOptions.date
                showingDatePicker = true
            }
            if overrides.date != nil {
                Button("Use Date from Text") { overrides.date = nil }
            }
        } label: { pill(dateLabel) }
        .accessibilityLabel("Date")
        .accessibilityValue(dateLabel)
        .accessibilityIdentifier("quickEventDate")
    }

    private var categoryMenu: some View {
        Menu {
            Button {
                overrides.categoryName = ""
            } label: {
                Label("None", systemImage: draft.categoryOptions.selectedCategory == nil ? "checkmark" : "tag")
            }
            ForEach(categories, id: \.name) { category in
                Button {
                    overrides.categoryName = category.name
                } label: {
                    Label(category.name, systemImage: draft.categoryOptions.selectedCategory == category.name ? "checkmark" : "tag")
                }
            }
            if overrides.categoryName != nil {
                Divider()
                Button("Use Text or Default") { overrides.categoryName = nil }
            }
        } label: { pill(draft.categoryOptions.selectedCategory ?? "None") }
        .accessibilityLabel("Category")
        .accessibilityValue(draft.categoryOptions.selectedCategory ?? "None")
        .accessibilityIdentifier("quickEventCategory")
    }

    private var repeatMenu: some View {
        Menu {
            ForEach(RepeatOption.allCases, id: \.self) { option in
                Button {
                    var options = draft.dateOptions
                    options.repeatOption = option
                    options.showRepeatOptions = option != .never
                    if option == .custom {
                        isFocused = false
                        repeatDraft = options
                        showingRepeatPicker = true
                    } else {
                        overrides.repeatOptions = options
                    }
                } label: {
                    Label(option.rawValue, systemImage: draft.dateOptions.repeatOption == option ? "checkmark" : "repeat")
                }
            }
            Button("Repeat Options…") {
                isFocused = false
                repeatDraft = draft.dateOptions
                showingRepeatPicker = true
            }
            if overrides.repeatOptions != nil {
                Button("Use Text or Default") { overrides.repeatOptions = nil }
            }
        } label: { pill(repeatLabel) }
        .accessibilityLabel("Repeat")
        .accessibilityValue(repeatLabel)
        .accessibilityIdentifier("quickEventRepeat")
    }
}

private struct QuickRepeatEditor: View {
    @State var options: DateOptions
    @State private var usesCustomRepeat = true
    var onSave: (DateOptions) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                RepeatSection(dateOptions: $options, useCustomRepeatOptions: $usesCustomRepeat)
                if let message = options.validationMessage {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(options) }
                        .disabled(options.validationMessage != nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
