//
//  ResetPasswordScreen.swift
//  Jesuit
//
//  Created by admin on 27/11/25.
//

import SwiftUI

struct ResetPasswordScreen: View {
    @Injected private var navigation: NavigationService
    @State var presenter = AppDI.shared.resolver(ResetPasswordPresenter.self)
    @FocusState private var focusedField: AppField?

    var text = "Your new password must be at least 8 characters long."

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Update Your Password")
                .customFont(.bold, 25)
                .foregroundStyle(.title)
                .padding(.top, 19)

            Text(text)
                .customFont(.medium, 18)
                .foregroundStyle(.subtitle)
                .lineLimit(2)
                .padding(.bottom)

            PrimaryTextField(
                text: $presenter.oldText,
                title: "Old Password",
                hint: "Enter your old password",
                keyboard: .asciiCapable,
                isSecure: true
            )
            .focused($focusedField, equals: .oldPassword)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .newPassword
            }

            PrimaryTextField(
                text: $presenter.newText,
                title: "New Password",
                hint: "Enter your new password",
                keyboard: .asciiCapable,
                isSecure: true
            )
            .focused($focusedField, equals: .newPassword)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .confirmPassword
            }

            PrimaryTextField(
                text: $presenter.confirmText,
                title: "Confirm New Password",
                hint: "Confirm your new password",
                keyboard: .asciiCapable,
                isSecure: true
            )
            .focused($focusedField, equals: .confirmPassword)
            Spacer()
            Button(
                action: { navigation.pop() },
                label: {
                    Text("Update Password")
                        .font(.customFont(.medium, 20))
                        .foregroundStyle(.white)
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.accent)
            .cornerRadius(12)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background1.ignoresSafeArea()
            .onTapGesture {
                focusedField = nil
            }
        )
        .onDisappear {
            focusedField = nil
        }
        .hotReloadable()
    }
}
