import SwiftUI

struct QuickAddEventField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @Binding var overrides: QuickEventOverrides
    var draft: NewEventDraft
    var categories: [(name: String, color: Color)]
    var onSubmit: () -> Void
    var onEdit: () -> Void
    var onDismiss: () -> Void

    @State private var dateDraft: QuickScheduleEditorDraft?
    @State private var repeatDraft: QuickScheduleEditorDraft?

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(draft.categoryOptions.selectedColor.color)
                    .frame(width: 10, height: 10)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                    .accessibilityHidden(true)
                TextField("Add an event, like Dune 12/18", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
                    .focused($isFocused)
                    .accessibilityLabel("Quick event entry")
                    .accessibilityHint("Type an event. The date, category and repeat buttons update as you type.")
                    .accessibilityIdentifier("quickEventInput")
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
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
                .accessibilityIdentifier("quickEventPills")
                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit event details")
                .accessibilityIdentifier("manualEventInput")
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

    private func pill(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemFill), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
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
        } label: { pill(dateLabel, icon: "calendar") }
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
        } label: { pill(draft.categoryOptions.selectedCategory ?? "None", icon: "tag") }
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
                        repeatDraft = QuickScheduleEditorDraft(options: options)
                    } else {
                        overrides.repeatOptions = options
                    }
                } label: {
                    Label(option.rawValue, systemImage: draft.dateOptions.repeatOption == option ? "checkmark" : "repeat")
                }
            }
            Button("Repeat Options…") {
                isFocused = false
                repeatDraft = QuickScheduleEditorDraft(options: draft.dateOptions)
            }
            if overrides.repeatOptions != nil {
                Button("Use Text or Default") { overrides.repeatOptions = nil }
            }
        } label: { pill(repeatLabel, icon: "repeat") }
        .accessibilityLabel("Repeat")
        .accessibilityValue(repeatLabel)
        .accessibilityIdentifier("quickEventRepeat")
    }
}

// Item-driven presentation initializes each editor with the current parsed
// values, including on its first presentation.
private struct QuickScheduleEditorDraft: Identifiable {
    let id = UUID()
    var options: DateOptions
}

private struct QuickDateEditor: View {
    @State var options: DateOptions
    var onSave: (Date, Date?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start date", selection: $options.date, displayedComponents: .date)
                    .onChange(of: options.date) { _, date in options.endDate = max(date, options.endDate) }
                Toggle("End date", isOn: $options.showEndDate)
                if options.showEndDate {
                    DatePicker("End date", selection: $options.endDate, in: options.date..., displayedComponents: .date)
                }
            }
            .accessibilityIdentifier("quickDatePicker")
            .navigationTitle("Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let calendar = Calendar.current
                        onSave(calendar.startOfDay(for: options.date),
                               options.showEndDate ? calendar.startOfDay(for: options.endDate) : nil)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
