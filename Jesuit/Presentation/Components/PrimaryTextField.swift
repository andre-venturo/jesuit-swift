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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .customFont(.medium, 16)
                .foregroundStyle(.title)

            HStack {
                Group {
                    if isSecure && isHidden {
                        SecureField(
                            "",
                            text: $text,
                            prompt: Text(hint).customFont(.regular, 16).foregroundStyle(.subtitle)
                        )
                    } else {
                        TextField(
                            "",
                            text: $text,
                            prompt: Text(hint).customFont(.regular, 16).foregroundStyle(.subtitle)
                        )
                    }
                }
                .font(.customFont(.regular, 16))
                .foregroundStyle(.title)
                .keyboardType(keyboard)
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
