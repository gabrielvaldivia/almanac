import SwiftUI

struct QuickAddEventField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @Binding var overrides: QuickEventOverrides
    var draft: NewEventDraft
    var categories: [(name: String, color: Color)]
    var onSubmit: () -> Void
    var validationMessage: String?
    var onDismiss: () -> Void

    @State private var dateDraft: QuickScheduleEditorDraft?
    @State private var repeatDraft: QuickScheduleEditorDraft?
    @Environment(\.colorScheme) private var colorScheme

    private var dateLabel: String {
        let calendar = Calendar.current
        let date = draft.dateOptions.date
        if draft.dateOptions.showEndDate {
            let end = draft.dateOptions.endDate
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: end)
            let currentYear = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
            if sameYear && currentYear && calendar.component(.month, from: date) == calendar.component(.month, from: end) {
                return "\(date.formatted(.dateTime.month(.abbreviated).day()))–\(end.formatted(.dateTime.day()))"
            }
            let format: Date.FormatStyle = sameYear && currentYear
                ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().year(.twoDigits)
            return "\(date.formatted(format)) – \(end.formatted(format))"
        }
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

    private var submitForeground: Color {
        let color = draft.categoryOptions.selectedColor
        let brightness = color.red * 0.299 + color.green * 0.587 + color.blue * 0.114
        return brightness > 0.5 ? .black : .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 4) {
                colorMenu
                TextField("Add an event, like Dune 12/18", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
                    .focused($isFocused)
                    .accessibilityLabel("Quick event entry")
                    .accessibilityHint("Type an event. The date, category and repeat buttons update as you type.")
                    .accessibilityIdentifier("quickEventInput")
            }
            .padding(.trailing, 8)
            .padding(.top, 4)
            .padding(.bottom, 4)

            HStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        dateMenu
                        categoryMenu
                        repeatMenu
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .padding(.leading, 8)
                .accessibilityIdentifier("quickEventPills")
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(submitForeground)
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
            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .accessibilityIdentifier("quickEventValidation")
            }
        }
        .padding(8)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 30 && value.translation.height > abs(value.translation.width) {
                        onDismiss()
                    }
                }
        )
        .accessibilityAction(named: "Collapse event entry", onDismiss)
        .sheet(item: $dateDraft) { draft in
            QuickDateEditor(options: draft.options) { date, endDate in
                overrides.date = date
                overrides.endDate = endDate
                dateDraft = nil
            }
        }
        .sheet(item: $repeatDraft) { draft in
            QuickRepeatEditor(options: draft.options) {
                overrides.repeatOptions = $0
                repeatDraft = nil
            }
        }
    }

    private func pill(_ title: String, icon: String, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
            .font(.caption.weight(.medium))
            .foregroundStyle(isSelected ? Color.blue : Color(uiColor: .secondaryLabel))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemFill), in: Capsule())
            .clipShape(Capsule())
            // The lifted menu preview follows the visible pill, while the
            // separate interaction shape below keeps its 44-point tap target.
            .contentShape(.contextMenuPreview, Capsule())
            .frame(minHeight: 44)
            .contentShape(.interaction, Rectangle())
    }

    private var colorMenu: some View {
        let choices = CustomColorPickerSheet.colorChoices(for: colorScheme)
        let selected = draft.categoryOptions.selectedColor
        let selectedName = CustomColorPickerSheet.colorName(for: selected, scheme: colorScheme)
        return Menu {
            ForEach(choices, id: \.name) { choice in
                Button {
                    overrides.color = CodableColor(color: choice.color)
                } label: {
                    Label {
                        Text(choice.name)
                    } icon: {
                        let symbol = selectedName == choice.name ? "checkmark.circle.fill" : "circle.fill"
                        Image(uiImage: UIImage(systemName: symbol)!.withTintColor(
                            UIColor(choice.color), renderingMode: .alwaysOriginal))
                    }
                }
            }
            if overrides.color != nil {
                Divider()
                Button("Use Category Color") { overrides.color = nil }
            }
        } label: {
            Circle()
                .fill(selected.color)
                .frame(width: 20, height: 20)
                .contentShape(.contextMenuPreview, Circle())
                .frame(width: 44, height: 44)
                .contentShape(.interaction, Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Event color")
        .accessibilityValue(selectedName)
        .accessibilityHint("Choose a color for this event.")
        .accessibilityIdentifier("quickEventColor")
    }

    private var dateMenu: some View {
        Menu {
            Button("Today") {
                overrides.date = Calendar.current.startOfDay(for: Date())
                overrides.endDate = nil
            }
            Button("Tomorrow") {
                overrides.date = Calendar.current.date(byAdding: .day, value: 1,
                                                        to: Calendar.current.startOfDay(for: Date()))
                overrides.endDate = nil
            }
            Button("Choose Dates…") {
                isFocused = false
                dateDraft = QuickScheduleEditorDraft(options: draft.dateOptions)
            }
            if draft.dateOptions.showEndDate {
                Button("Remove End Date") {
                    overrides.date = draft.dateOptions.date
                    overrides.endDate = nil
                }
            }
            if overrides.date != nil {
                Button("Use Date from Text") { overrides.date = nil; overrides.endDate = nil }
            }
        } label: { pill(dateLabel, icon: "calendar", isSelected: true) }
        .buttonStyle(.plain)
        .accessibilityLabel("Date")
        .accessibilityValue(dateLabel)
        .accessibilityIdentifier("quickEventDate")
        .accessibilityAddTraits(.isSelected)
    }

    private var categoryMenu: some View {
        Menu {
            Button {
                overrides.categoryName = ""
            } label: {
                if draft.categoryOptions.selectedCategory == nil { Label("None", systemImage: "checkmark") }
                else { Text("None") }
            }
            ForEach(categories, id: \.name) { category in
                Button {
                    overrides.categoryName = category.name
                } label: {
                    if draft.categoryOptions.selectedCategory == category.name { Label(category.name, systemImage: "checkmark") }
                    else { Text(category.name) }
                }
            }
            if overrides.categoryName != nil {
                Divider()
                Button("Use Text or Default") { overrides.categoryName = nil }
            }
        } label: { pill(draft.categoryOptions.selectedCategory ?? "None", icon: "tag", isSelected: draft.hasCategorySelection) }
        .buttonStyle(.plain)
        .accessibilityLabel("Category")
        .accessibilityValue(draft.categoryOptions.selectedCategory ?? "None")
        .accessibilityIdentifier("quickEventCategory")
        .accessibilityAddTraits(draft.hasCategorySelection ? .isSelected : [])
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
                        repeatDraft = QuickScheduleEditorDraft(options: options)
                    } else {
                        overrides.repeatOptions = options
                    }
                } label: {
                    if draft.dateOptions.repeatOption == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
            if overrides.repeatOptions != nil {
                Button("Use Text or Default") { overrides.repeatOptions = nil }
            }
        } label: { pill(repeatLabel, icon: "repeat", isSelected: draft.hasRepeatSelection) }
        .buttonStyle(.plain)
        .accessibilityLabel("Repeat")
        .accessibilityValue(repeatLabel)
        .accessibilityIdentifier("quickEventRepeat")
        .accessibilityAddTraits(draft.hasRepeatSelection ? .isSelected : [])
    }
}

// Item-driven presentation initializes each editor with the current parsed
// values, including on its first presentation.
private struct QuickScheduleEditorDraft: Identifiable {
    let id = UUID()
    var options: DateOptions
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
    let id: String
    let namespace: Namespace.ID
    var isInteractive = false
    var tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint).interactive(isInteractive), in: RoundedRectangle(cornerRadius: 28))
                .glassEffectID(id, in: namespace)
        } else {
            content
                .background {
                    if let tint {
                        RoundedRectangle(cornerRadius: 28).fill(tint)
                    } else {
                        RoundedRectangle(cornerRadius: 28).fill(.regularMaterial)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
                .matchedGeometryEffect(id: id, in: namespace, anchor: .bottomTrailing)
        }
    }
}
