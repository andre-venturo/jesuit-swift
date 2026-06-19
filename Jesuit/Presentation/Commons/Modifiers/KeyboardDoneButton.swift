//
//  KeyboardDoneButton.swift
//  Jesuit
//
//  Adds a trailing "Selesai" (Done) button to the keyboard accessory toolbar so
//  number-pad fields — which have no return key — can dismiss the keyboard.
//  Apply `.keyboardDoneButton()` to a `TextField`/`TextEditor`.
//

import SwiftUI

private struct KeyboardDoneButton: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused {
                        Spacer()
                        Button("Selesai") { isFocused = false }
                            .foregroundStyle(.accent)
                    }
                }
            }
    }
}

extension View {
    /// Shows a "Selesai" button above the keyboard while this field is focused.
    func keyboardDoneButton() -> some View {
        modifier(KeyboardDoneButton())
    }
}
