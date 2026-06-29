//
//  DismissKeyboardOnTap.swift
//  Jesuit
//
//  Flutter's `GestureDetector(onTap: () => FocusScope.of(context).unfocus())`
//  equivalent: installs ONE window-wide tap recognizer that ends editing on any
//  tap not consumed by a text field. `cancelsTouchesInView = false` so buttons,
//  list rows, links etc. still get their taps — the keyboard just also closes.
//  Apply `.dismissKeyboardOnTap()` once at the app root.
//

import SwiftUI
import UIKit

private final class KeyboardDismisser {
    static let shared = KeyboardDismisser()
    private var installed = false

    func install() {
        guard !installed,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: \.isKeyWindow)
        else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        tap.cancelsTouchesInView = false
        window.addGestureRecognizer(tap)
        installed = true
    }

    @objc private func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Dismiss the keyboard on a tap anywhere outside a text field. Apply once at the root.
    func dismissKeyboardOnTap() -> some View {
        // ponytail: retries on each onAppear until a key window exists, then no-ops.
        onAppear { KeyboardDismisser.shared.install() }
    }
}
