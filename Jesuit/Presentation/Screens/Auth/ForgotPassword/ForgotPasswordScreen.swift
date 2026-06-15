//
//  ForgotPasswordScreen.swift
//  Jesuit
//
//  Created by admin on 25/11/25.
//

import SwiftUI

struct ForgotPasswordScreen: View {
    @Injected private var navigation: NavigationService
    @State var presenter = AppDI.shared.resolver(LoginPresenter.self)
    @FocusState private var focusedField: AppField?

    var text = "Enter the email address associated with your account "
    var text1 = "and we'll send you a link to reset your password."

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Forgot Password")
                .customFont(.bold, 25)
                .foregroundStyle(.title)
                .padding(.top, 19)

            Text(text + text1)
                .customFont(.medium, 18)
                .foregroundStyle(.subtitle)
                .animation(.smooth, value: focusedField)
                
            PrimaryTextField(
                text: $presenter.emailText,
                title: "Email Address",
                hint: "Enter your email",
                keyboard: .emailAddress,
                isSecure: false
            )
            .focused($focusedField, equals: .email)
            .padding(.top, 30)

            Spacer()
            Button(
                action: { navigation.popTo(root: .home) },
                label: {
                    Text("Send Reset Link")
                        .font(.customFont(.medium, 20))
                        .foregroundStyle(.white)
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.accent)
            .cornerRadius(12)

            Button("Back To Login") {
                navigation.pop()
            }
            .font(.customFont(.medium, 16))
            .foregroundStyle(.mySecondary)
            .frame(maxWidth: screenBounds.width, alignment: .center)
            .padding(.vertical, 4)
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
