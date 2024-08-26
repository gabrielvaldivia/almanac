 //
//  FontModifier.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/28/24.
//

import SwiftUI

struct RoundedFontModifier: ViewModifier {
    var style: Font.TextStyle

    func body(content: Content) -> some View {
        content
            .font(.system(style, design: .rounded))
    }
}

extension View {
    func roundedFont(_ style: Font.TextStyle) -> some View {
        self.modifier(RoundedFontModifier(style: style))
    }
}
