import Foundation
import SwiftUI
import WidgetKit
import UserNotifications

struct EditEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event? {
        didSet {
            if let event = selectedEvent {
                newEventTitle = event.title
                newEventDate = event.date
                newEventEndDate = event.endDate ?? Calendar.current.date(byAdding: .day, value: 1, to: event.date) ?? Date()
                showEndDate = event.endDate != nil
                selectedCategory = event.category
                selectedColor = event.color
                notificationsEnabled = event.notificationsEnabled
                repeatOption = event.repeatOption
                repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                repeatUntilOption = event.repeatUntil == nil ? .indefinitely : .onDate
            }
        }
    }
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showEditSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor
    @Binding var notificationsEnabled: Bool
    @State private var repeatOption: RepeatOption = .never
    @State private var repeatUntil: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely
    @State private var repeatCount: Int = 1
    @State private var showDeleteActionSheet = false
    @State private var deleteOption: DeleteOption = .thisEvent
    @State private var newCategoryColor: Color = .blue
    @State private var newCategoryName: String = ""
    @State private var showAddCategorySheet: Bool = false
    @FocusState private var isTitleFocused: Bool
    var saveEvent: () -> Void
    @EnvironmentObject var appData: AppData

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    // Name Section
                    VStack {
                        HStack {
                            Text("Name")
                                .font(.headline)
                                .padding(.top)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        
                        HStack {
                            TextField("Title", text: $newEventTitle)
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                .background(isTitleFocused ? Color(UIColor.systemBackground) : Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isTitleFocused ? getCategoryColor() : Color.clear, lineWidth: 1)
                                )
                                .focused($isTitleFocused)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Date Section
                    VStack {
                        HStack {
                            Text("Date")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.top)
                            Spacer()
                        }
                        
                        HStack {
                            DatePicker("", selection: $newEventDate, displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle())
                                .labelsHidden()
                            
                            if showEndDate {
                                DatePicker("", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                    .datePickerStyle(DefaultDatePickerStyle())
                                    .labelsHidden()
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showEndDate.toggle()
                                if !showEndDate {
                                    newEventEndDate = Date()
                                } else {
                                    newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date()
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(showEndDate ? getCategoryColor() : Color.gray.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: showEndDate ? "calendar.badge.minus" : "calendar.badge.plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(showEndDate ? .white : .gray)
                                }
                            }
                            
                            Menu {
                                Picker("Repeat", selection: $repeatOption) {
                                    ForEach(RepeatOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(repeatOption == .never ? Color.gray.opacity(0.2) : getCategoryColor())
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "repeat")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(repeatOption == .never ? .gray : .white)
                                }
                            }
                        }
                        .padding(.horizontal, 0)
                        
                        if repeatOption != .never {
                            VStack(alignment: .leading) {
                                Button(action: { repeatUntilOption = .indefinitely }) {
                                    HStack {
                                        Image(systemName: repeatUntilOption == .indefinitely ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 24))
                                            .fontWeight(.light)
                                            .foregroundColor(repeatUntilOption == .indefinitely ? getCategoryColor() : .gray)
                                        Text("Repeat \(repeatOption.rawValue.lowercased()) indefinitely")
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 36)
                                    .padding(.top, 10)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                HStack {
                                    Button(action: { repeatUntilOption = .onDate }) {
                                        HStack {
                                            Image(systemName: repeatUntilOption == .onDate ? "largecircle.fill.circle" : "circle")
                                                .font(.system(size: 24))
                                                .fontWeight(.light)
                                                .foregroundColor(repeatUntilOption == .onDate ? getCategoryColor() : .gray)
                                            Text("Repeat \(repeatOption.rawValue.lowercased()) until")
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: 36)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Spacer()
                                    if repeatUntilOption == .onDate {
                                        DatePicker("", selection: $repeatUntil, displayedComponents: .date)
                                            .datePickerStyle(DefaultDatePickerStyle())
                                            .labelsHidden()
                                    }
                                }
                                
                                HStack {
                                    Button(action: { repeatUntilOption = .after }) {
                                        HStack {
                                            Image(systemName: repeatUntilOption == .after ? "largecircle.fill.circle" : "circle")
                                                .font(.system(size: 24))
                                                .fontWeight(.light)
                                                .foregroundColor(repeatUntilOption == .after ? getCategoryColor() : .gray)
                                            Text("End after")
                                        }
                                        .frame(alignment: .leading)
                                        .frame(height: 36)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if repeatUntilOption == .after {
                                        HStack {
                                            TextField("", value: $repeatCount, formatter: NumberFormatter())
                                                .keyboardType(.numberPad)
                                                .frame(width: 24)
                                                .multilineTextAlignment(.center)
                                            Stepper(value: $repeatCount, in: 1...100) {
                                                Text(" times")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Category Section
                    VStack {
                        HStack {
                            Text("Category")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.top)
                                .padding(.horizontal)
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(appData.categories, id: \.name) { category in
                                    Text(category.name)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category.name ? getCategoryColor() : Color.gray.opacity(0.15))
                                        .cornerRadius(20)
                                        .foregroundColor(selectedCategory == category.name ? .white : .primary)
                                        .onTapGesture {
                                            selectedCategory = category.name
                                        }
                                }
                                // New category pill
                                Button(action: {
                                    selectedCategory = nil
                                    showAddCategorySheet = true
                                    newCategoryName = ""
                                    newCategoryColor = Color(red: Double.random(in: 0.1...0.9), green: Double.random(in: 0.1...0.9), blue: Double.random(in: 0.1...0.9))
                                }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("New Category")
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                    }
                    
                    // Notification Section
                    HStack {
                        Toggle(isOn: $notificationsEnabled) {
                            Text("Notify me")
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: getCategoryColor()))
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button(action: {
                        showEditSheet = false
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveEvent()
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(getCategoryColor())
                                    .frame(width: 60, height: 32)
                                Text("Save")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(newEventTitle.isEmpty ? 0.3 : 1.0)
                    }
                    .disabled(newEventTitle.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete Event") {
                        if selectedEvent?.repeatOption != .never {
                            showDeleteActionSheet = true
                        } else {
                            deleteEvent()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .actionSheet(isPresented: $showDeleteActionSheet) {
                ActionSheet(
                    title: Text("Delete Event"),
                    message: Text("Are you sure you want to delete this event?"),
                    buttons: [
                        .destructive(Text("Delete this event")) {
                            deleteOption = .thisEvent
                            deleteEvent()
                        },
                        .destructive(Text("Delete this and all upcoming events")) {
                            deleteOption = .thisAndUpcoming
                            deleteEvent()
                        },
                        .destructive(Text("Delete all events in this series")) {
                            deleteOption = .allEvents
                            deleteEvent()
                        },
                        .cancel()
                    ]
                )
            }
        }
        .onAppear {
            if let event = selectedEvent {
                notificationsEnabled = event.notificationsEnabled
                repeatOption = event.repeatOption
                repeatUntil = event.repeatUntil ?? Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                repeatUntilOption = event.repeatUntil == nil ? .indefinitely : .onDate
            }
            isTitleFocused = true // Focus the TextField when the sheet appears
        }
    }

    func deleteEvent() {
        guard let event = selectedEvent else { return }
        
        if event.repeatOption == .never {
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events.remove(at: index)
            }
        } else {
            switch deleteOption {
            case .thisEvent:
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events.remove(at: index)
                }
            case .thisAndUpcoming:
                events.removeAll { $0.id == event.id || ($0.repeatOption == event.repeatOption && $0.date >= event.date) }
            case .allEvents:
                events.removeAll { $0.id == event.id || $0.repeatOption == event.repeatOption }
            }
        }
        
        saveEvents()
        showEditSheet = false
    }

    func getCategoryColor() -> Color {
        if let selectedCategory = selectedCategory,
           let category = appData.categories.first(where: { $0.name == selectedCategory }) {
            return category.color
        }
        return Color.blue
    }

    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
        } else {
            print("Failed to encode events.")
        }
    }
    
    func calculateRepeatUntilDate(for option: RepeatOption, from startDate: Date, count: Int) -> Date? {
        switch option {
        case .never:
            return nil
        case .daily:
            return Calendar.current.date(byAdding: .day, value: count - 1, to: startDate)
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: count - 1, to: startDate)
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: count - 1, to: startDate)
        case .yearly:
            return Calendar.current.date(byAdding: .year, value: count - 1, to: startDate)
        }
    }
    
    func generateRepeatingEvents(for event: Event) -> [Event] {
        var repeatingEvents = [Event]()
        var currentEvent = event
        repeatingEvents.append(currentEvent)
        
        var repetitionCount = 1
        let maxRepetitions: Int
        
        switch repeatUntilOption {
        case .indefinitely:
            maxRepetitions = 100
        case .after:
            maxRepetitions = repeatCount
        case .onDate:
            maxRepetitions = 100
        }
        
        while let nextDate = getNextRepeatDate(for: currentEvent), 
              nextDate <= (event.repeatUntil ?? Date.distantFuture), 
              repetitionCount < maxRepetitions {
            currentEvent = Event(
                title: event.title,
                date: nextDate,
                endDate: event.endDate,
                color: event.color,
                category: event.category,
                notificationsEnabled: event.notificationsEnabled,
                repeatOption: event.repeatOption,
                repeatUntil: event.repeatUntil
            )
            repeatingEvents.append(currentEvent)
            repetitionCount += 1
        }
        
        return repeatingEvents
    }
    
    func getNextRepeatDate(for event: Event) -> Date? {
        switch event.repeatOption {
        case .never:
            return nil
        case .daily:
            return Calendar.current.date(byAdding: .day, value: 1, to: event.date)
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: event.date)
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: 1, to: event.date)
        case .yearly:
            return Calendar.current.date(byAdding: .year, value: 1, to: event.date)
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM, d, yyyy"
        return formatter
    }
}

// Preview Provider
struct EditEventView_Previews: PreviewProvider {
    static var previews: some View {
        EditEventView(
            events: .constant([]),
            selectedEvent: .constant(nil),
            newEventTitle: .constant(""),
            newEventDate: .constant(Date()),
            newEventEndDate: .constant(Date()),
            showEndDate: .constant(false),
            showEditSheet: .constant(false),
            selectedCategory: .constant(nil),
            selectedColor: .constant(CodableColor(color: .black)),
            notificationsEnabled: .constant(true),
            saveEvent: {}
        )
        .environmentObject(AppData())
    }
}