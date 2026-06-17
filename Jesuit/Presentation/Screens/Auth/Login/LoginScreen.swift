//
//  LoginScreen.swift
//  Jesuit
//
//  Created by admin on 23/11/25.
//

import SwiftUI

struct LoginScreen: View {
    @Injected private var navigation: NavigationService
    @State var presenter = AppDI.shared.resolver(LoginPresenter.self)
    @FocusState private var focusedField: AppField?

    var body: some View {
        VStack(spacing: 16) {
            Image(.imageLogin)
                .resizable()
                .scaledToFit()
                .frame(width: 60)
                .padding(.bottom, 20)
                .animation(.smooth, value: focusedField)
                .opacity(focusedField != nil ? 0.0 : 1.0)

            Text("Welcome Back!")
                .customFont(.bold, 30)
                .foregroundStyle(.title)

            Text("Log in to continue")
                .customFont(.medium, 18)
                .foregroundStyle(.subtitle)

            PrimaryTextField(
                text: $presenter.emailText,
                title: "Email or Username",
                hint: "Enter your email or username",
                keyboard: .emailAddress,
                isSecure: false
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }

            PrimaryTextField(
                text: $presenter.passText,
                title: "Password",
                hint: "Enter your password",
                keyboard: .asciiCapable,
                isSecure: true
            )
            .focused($focusedField, equals: .password)

            if let error = presenter.errorMessage {
                Text(error)
                    .customFont(.medium, 14)
                    .foregroundStyle(.expense)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(
                action: {
                    focusedField = nil
                    Task {
                        if await presenter.login() {
                            navigation.navigate(to: .home)
                        }
                    }
                },
                label: {
                    Group {
                        if presenter.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Login")
                                .font(.customFont(.medium, 20))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.accent)
                    .cornerRadius(12)
                }
            )
            .disabled(presenter.isLoading)
            .padding(.vertical, 20)

            HStack {
                Text("Don't have an account?")
                    .customFont(.medium, 16)
                    .foregroundStyle(.subtitle)

                Button("Register") {
                    navigation.navigate(to: .register)
                }
                .font(.customFont(.medium, 16))
                .foregroundStyle(.mySecondary)
            }
            .animation(.smooth, value: focusedField)
            .opacity(focusedField != nil ? 0.0 : 1.0)
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
