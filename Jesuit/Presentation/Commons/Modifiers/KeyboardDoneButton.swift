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
    let enabled: Bool
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if enabled && isFocused {
                        Spacer()
                        Button("Selesai") { isFocused = false }
                            .foregroundStyle(.accent)
                    }
                }
            }
    }
}

extension UIKeyboardType {
    /// Number-style keyboards have no return key, so they need the "Selesai" accessory
    /// to dismiss; everything else dismisses via its return key (+ tap-outside).
    var hasNoReturnKey: Bool {
        switch self {
        case .numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad: return true
        default: return false
        }
    }
}

extension View {
    /// Shows a "Selesai" button above the keyboard while focused — but only for
    /// keyboards that lack a return key (number pads). Pass the field's keyboard type;
    /// it defaults to `.numberPad` for the currency fields that call it bare.
    /// Pass `force: true` for multi-line fields, whose return key inserts a newline
    /// instead of dismissing.
    func keyboardDoneButton(for keyboard: UIKeyboardType = .numberPad, force: Bool = false) -> some View {
        modifier(KeyboardDoneButton(enabled: force || keyboard.hasNoReturnKey))
    }
}
