//
//  CoreTextModifier.swift
//  Jesuit
//
//  Created by admin on 24/11/25.
//

import SwiftUI

struct CoreTextModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.textFieldBG)
            .cornerRadius(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? .accent : .textFieldStroke, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
