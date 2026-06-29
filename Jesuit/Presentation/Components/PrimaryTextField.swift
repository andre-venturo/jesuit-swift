//
//  PrimaryTextField.swift
//  Jesuit
//
//  Created by admin on 24/11/25.
//

import SwiftUI

struct PrimaryTextField: View {
    @State private var isHidden: Bool = false

    @Binding var text: String
    var title: LocalizedStringKey
    var hint: LocalizedStringKey
    var keyboard: UIKeyboardType
    var isSecure: Bool
    /// Return-key label (Android `imeOptions` equivalent): `.done` / `.next` / `.go`…
    var submitLabel: SubmitLabel = .done
    /// Fired when the return key is pressed — e.g. advance focus or submit the form.
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .customFont(.medium, Typography.body)
                .foregroundStyle(.title)

            HStack {
                Group {
                    if isSecure && isHidden {
                        SecureField(
                            "",
                            text: $text,
                            prompt: Text(hint).customFont(.regular, Typography.body).foregroundStyle(.subtitle)
                        )
                    } else {
                        TextField(
                            "",
                            text: $text,
                            prompt: Text(hint).customFont(.regular, Typography.body).foregroundStyle(.subtitle)
                        )
                    }
                }
                .font(.customFont(.regular, Typography.body))
                .foregroundStyle(.title)
                .keyboardType(keyboard)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
                .keyboardDoneButton(for: keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .disableAutocorrection(true)

                if isSecure {
                    Button("", systemImage: isHidden ? "eye.slash" : "eye") {
                        isHidden.toggle()
                    }
                    .foregroundStyle(.title.opacity(0.9))
                }
            }
            .coreTextFieldStyle()
        }
        .onAppear {
            isHidden = isSecure
        }
    }
}
