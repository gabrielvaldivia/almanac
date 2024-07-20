//
//  CategoriesView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UIKit
import WidgetKit
import StoreKit
import GoogleSignIn

extension Color {
    func toHex() -> String? {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0
        let g: CGFloat = components?[1] ?? 0
        let b: CGFloat = components?[2] ?? 0
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

struct PresentingViewController: UIViewControllerRepresentable {
    var onPresent: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        DispatchQueue.main.async {
            self.onPresent(viewController)
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct CategoriesView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingAddCategorySheet = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.blue  // Default color for new category
    @FocusState private var isCategoryNameFieldFocused: Bool  // Add this line
    @State private var showingDeleteAllAlert = false
    @State private var selectedCategory: String?  // Add this line
    @State private var tempCategoryNames: [String] = []  // Temporary storage for category names
    @Environment(\.editMode) private var editMode  // Access the edit mode
    @State private var showingEditCategorySheet = false  // Add this line
    @State private var categoryToEdit: (index: Int, name: String, color: Color)?  // Add this line
    @State private var showingSubscriptionSheet = false  // Add this line
    @State private var isGoogleSignedIn = false
    @State private var presentGoogleSignIn = false

    var body: some View {
        Form {  // Change List to Form
            // Categories section 
            Section() {
                ForEach(appData.categories.indices, id: \.self) { index in
                    HStack {
                        if editMode?.wrappedValue == .active {
                            TextField("Category Name", text: Binding(
                                get: { 
                                    if self.tempCategoryNames.indices.contains(index) {
                                        return self.tempCategoryNames[index]
                                    }
                                    return ""
                                },
                                set: { 
                                    if self.tempCategoryNames.indices.contains(index) {
                                        self.tempCategoryNames[index] = $0
                                    }
                                }
                            ))
                        } else {
                            Text(self.appData.categories[index].name)
                        }
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { 
                                if self.appData.categories.indices.contains(index) {
                                    return self.appData.categories[index].color
                                }
                                return .clear
                            },
                            set: { 
                                if self.appData.categories.indices.contains(index) {
                                    self.appData.categories[index].color = $0
                                }
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                        .padding(.trailing, 10)
                    }
                    .contentShape(Rectangle())  // Make the entire HStack tappable
                    .onTapGesture {
                        if editMode?.wrappedValue != .active {
                            categoryToEdit = (index: index, name: appData.categories[index].name, color: appData.categories[index].color)
                            showingEditCategorySheet = true
                        }
                    }
                }
                .onDelete(perform: removeCategory)
                .onMove(perform: moveCategory)
            }
            
            // Add Category button
            HStack {
                Button(action: {
                    showingAddCategorySheet = true
                    newCategoryName = ""
                    newCategoryColor = Color(red: Double.random(in: 0.1...0.9), green: Double.random(in: 0.1...0.9), blue: Double.random(in: 0.1...0.9))  // Ensure middle range color
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Category")
                    }
                }
            }

            // Google Calendar section
            Section(header: Text("Google Calendar")) {
                if isGoogleSignedIn {
                    Button("Sign Out") {
                        signOut()
                    }
                } else {
                    Button("Import from Google Calendar") {
                        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                            importFromGoogleCalendar(presentingViewController: rootViewController)
                        }
                    }
                }
            }
        }
        .formStyle(GroupedFormStyle()) 
        .navigationBarTitle("Manage Categories", displayMode: .inline)
        .navigationBarItems(trailing: EditButton())  // Use the existing Edit button
        
        // Add Category View
        .sheet(isPresented: $showingAddCategorySheet) {
            NavigationView {
                AddCategoryView(showingAddCategorySheet: $showingAddCategorySheet) { newCategory in
                    appData.categories.append((name: newCategory.name, color: newCategory.color))
                    appData.saveCategories()  // Save categories to user defaults
                }
                .environmentObject(appData)
            }
            .presentationDetents([.medium])  // Add this line to set the sheet size to medium
        }
        
        // Edit Category Sheet
        .sheet(isPresented: $showingEditCategorySheet) {
            EditCategorySheet(categoryToEdit: $categoryToEdit, showingEditCategorySheet: $showingEditCategorySheet)
                .environmentObject(appData)
        }
        
        // Subscription Sheet
        /*
        .sheet(isPresented: $showingSubscriptionSheet) {
            SubscriptionSheet(isPresented: $showingSubscriptionSheet)
                .environmentObject(appData)
        }
        */
        .onAppear {
            appData.loadCategories()
            if appData.defaultCategory.isEmpty, let firstCategory = appData.categories.first?.name {
                appData.defaultCategory = firstCategory
            }
            checkGoogleSignInStatus()
        }
        .onChange(of: editMode?.wrappedValue) {
            if let newValue = editMode?.wrappedValue, newValue == .active {
                // Initialize tempCategoryNames with current category names
                tempCategoryNames = appData.categories.map { $0.name }
            } else {
                // Apply changes
                for index in appData.categories.indices {
                    if index < tempCategoryNames.count {
                        let oldName = appData.categories[index].name
                        let newName = tempCategoryNames[index]
                        if oldName != newName {
                            appData.categories[index].name = newName
                            updateEventsForCategoryChange(oldName: oldName, newName: newName)
                        }
                    }
                }
                appData.saveCategories()  // Save categories to user defaults
            }
        }
    }

    private func removeCategory(at offsets: IndexSet) {
        DispatchQueue.main.async {
            if let index = offsets.first, index < self.appData.categories.count {
                let removedCategory = self.appData.categories[index].name
                self.appData.categories.remove(at: index)
                appData.saveCategories()  // Save categories to user defaults
                
                // Update defaultCategory if the removed category was the default one
                if appData.defaultCategory == removedCategory {
                    appData.defaultCategory = appData.categories.first?.name ?? ""
                }
            }
        }
    }

    private func moveCategory(from source: IndexSet, to destination: Int) {
        DispatchQueue.main.async {
            appData.categories.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func updateDailyNotificationTime(_ time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Today's events"
        
        // Ensure appData is accessed correctly
        let todayEvents = appData.getTodayEvents()  // Corrected method name
        let eventTitles = todayEvents.map { $0.title }.joined(separator: ", ")
        content.body = eventTitles.isEmpty ? "No events due today." : eventTitles
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "dailyNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    private func updateEventsForCategoryChange(oldName: String, newName: String) {
        for i in 0..<appData.events.count {
            if appData.events[i].category == oldName {
                appData.events[i].category = newName
            }
        }
        appData.objectWillChange.send()  // Notify the view of changes
        appData.saveEvents()  // Save updated events to user defaults
    }
    
    private func deleteAllEvents() {
        appData.objectWillChange.send()  // Notify the view of changes
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
    }
    
    private func checkGoogleSignInStatus() {
        isGoogleSignedIn = GIDSignIn.sharedInstance.currentUser != nil
    }

    private func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isGoogleSignedIn = false
        
        // Clear any stored Google Sign-In data
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.removeObject(forKey: "GoogleSignInEmail")
            sharedDefaults.set(false, forKey: "IsGoogleSignedIn")
        }
        
        // Remove all Google Calendar events
        appData.events = appData.events.filter { !$0.isGoogleCalendarEvent }
        appData.saveEvents()
        
        // Clear any cached Google Calendar data
        appData.googleCalendarManager.clearEvents()
        
        // Reload widget to reflect changes
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
    }
    
    private func importFromGoogleCalendar(presentingViewController: UIViewController) {
        print("Import from Google Calendar tapped")  // Debugging statement
        Task {
            do {
                // This will handle both sign-in and fetching events
                try await appData.googleCalendarManager.signInAndFetchEvents(presentingViewController: presentingViewController)
                DispatchQueue.main.async {
                    self.isGoogleSignedIn = true
                    print("Successfully signed in and fetched events")  // Debugging statement
                    // Optionally, you can show a success message here
                }
            } catch {
                print("Error importing from Google Calendar: \(error)")  // Debugging statement
                // Handle the error appropriately, maybe show an alert to the user
            }
        }
    }
}

struct EditCategorySheet: View {
    @Binding var categoryToEdit: (index: Int, name: String, color: Color)?
    @Binding var showingEditCategorySheet: Bool
    @EnvironmentObject var appData: AppData
    @FocusState private var isCategoryNameFieldFocused: Bool

    var body: some View {
        NavigationView {
            if let categoryToEdit = categoryToEdit {
                Form {
                    TextField("Category Name", text: Binding(
                        get: { categoryToEdit.name },
                        set: { self.categoryToEdit?.name = $0 }
                    ))
                    .focused($isCategoryNameFieldFocused)  // Ensure the TextField is focused
                    ColorPicker("Choose Color", selection: Binding(
                        get: { categoryToEdit.color },
                        set: { self.categoryToEdit?.color = $0 }
                    ))
                    
                }
                .formStyle(GroupedFormStyle())  // Add this line
                .navigationBarTitle("Edit Category", displayMode: .inline)  // Add this line
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingEditCategorySheet = false
                    },
                    trailing: Button("Save") {
                        let index = categoryToEdit.index
                        appData.categories[index].name = categoryToEdit.name
                        appData.categories[index].color = categoryToEdit.color
                        appData.saveCategories()  // Save categories to user defaults
                        showingEditCategorySheet = false
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCategoryNameFieldFocused = true  // Delay focusing the TextField
            }
        }
        .presentationDetents([.medium])  // Ensure the sheet size is set to medium
    }
}