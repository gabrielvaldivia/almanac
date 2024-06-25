//
//  AppData.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

struct Event: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var endDate: Date?
    var color: CodableColor // Use CodableColor to store color
    var category: String?
}

struct CategoryData: Codable {
    var name: String
    var color: CodableColor // Use CodableColor to store color
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(color: Color) {
        if let components = UIColor(color).cgColor.components {
            self.red = Double(components[0])
            self.green = Double(components[1])
            self.blue = Double(components[2])
            self.opacity = Double(components[3])
        } else {
            self.red = 0
            self.green = 0
            self.blue = 0
            self.opacity = 1
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        opacity = try container.decode(Double.self, forKey: .opacity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(opacity, forKey: .opacity)
    }

    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
}

class AppData: ObservableObject {
    @Published var categories: [(name: String, color: Color)] = [
        ("Work", .blue),
        ("Social", .green),
        ("Birthdays", .red),
        ("Movies", .purple)
    ] {
        didSet {
            saveCategories()
        }
    }
    @Published var defaultCategory: String = "" {
        didSet {
            UserDefaults.standard.set(defaultCategory, forKey: "defaultCategory")
        }
    }

    // Ensure this method is defined only once
    func clearCategories() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") else {
            print("Failed to access shared UserDefaults.")
            return
        }
        sharedDefaults.removeObject(forKey: "categories")
        print("Categories cleared from UserDefaults.")
    }

    init() {
        // clearCategories() // Comment out or remove this line after testing
        loadCategories()
        defaultCategory = UserDefaults.standard.string(forKey: "defaultCategory") ?? ""
    }

    // Save categories to UserDefaults
    private func saveCategories() {
        let encoder = JSONEncoder()
        let categoryData = categories.map { CategoryData(name: $0.name, color: CodableColor(color: $0.color)) }
        do {
            let encodedData = try encoder.encode(categoryData)
            guard let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") else {
                print("Failed to access shared UserDefaults.")
                return
            }
            sharedDefaults.set(encodedData, forKey: "categories")
            print("Categories saved successfully: \(categoryData)")
        } catch {
            print("Failed to encode categories: \(error.localizedDescription)")
        }
    }

    // Load categories from UserDefaults
    func loadCategories() {
        let decoder = JSONDecoder()
        guard let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") else {
            print("Failed to access shared UserDefaults.")
            return
        }
        guard let data = sharedDefaults.data(forKey: "categories") else {
            print("No categories data found in UserDefaults.")
            self.categories = [
                ("Work", .blue),
                ("Social", .green),
                ("Birthdays", .red),
                ("Movies", .purple)
            ] // Default to all categories if nothing is loaded
            print("Default categories set: \(self.categories)")
            return
        }
        
        do {
            let decoded = try decoder.decode([CategoryData].self, from: data)
            self.categories = decoded.map { categoryData in
                return (name: categoryData.name, color: categoryData.color.color)
            }
            print("Decoded categories: \(self.categories)")
        } catch {
            print("Failed to decode categories: \(error.localizedDescription)")
            self.categories = [
                ("Work", .blue),
                ("Social", .green),
                ("Birthdays", .red),
                ("Movies", .purple)
            ] // Default to all categories if decoding fails
            print("Default categories set after decoding failure: \(self.categories)")
        }
    }
}
