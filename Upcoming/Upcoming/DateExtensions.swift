//
//  DateExtensions.swift
//  Upcoming
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import Foundation

extension Date {
    var midnight: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: self)
    }
}