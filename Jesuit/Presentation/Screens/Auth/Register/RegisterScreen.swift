//
//  RegisterScreen.swift
//  Jesuit
//
//  Created by admin on 24/11/25.
//

import SwiftUI

struct RegisterScreen: View {
    @Injected private var navigation: NavigationService
    @State var presenter = AppDI.shared.resolver(RegisterPresenter.self)
    @FocusState private var focusedField: AppField?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Create Account")
                    .customFont(.bold, 30)
                    .foregroundStyle(.title)
                    .animation(.smooth, value: focusedField)
                    .opacity(focusedField != nil ? 0.0 : 1.0)

                Text("Join us and start your journey")
                    .customFont(.medium, 18)
                    .foregroundStyle(.subtitle)
                    .padding(.top, -6)
                    .padding(.bottom, 20)
                    .animation(.smooth, value: focusedField)
                    .opacity(focusedField != nil ? 0.0 : 1.0)

                PrimaryTextField(
                    text: $presenter.nameText,
                    title: "Full Name",
                    hint: "Enter your full name",
                    keyboard: .default,
                    isSecure: false
                )
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .username
                }

                PrimaryTextField(
                    text: $presenter.usernameText,
                    title: "Username",
                    hint: "Choose a username",
                    keyboard: .default,
                    isSecure: false
                )
                .focused($focusedField, equals: .username)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .email
                }

                PrimaryTextField(
                    text: $presenter.emailText,
                    title: "Email",
                    hint: "Enter your email",
                    keyboard: .emailAddress,
                    isSecure: false
                )
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .phone
                }

                PrimaryTextField(
                    text: $presenter.phoneText,
                    title: "Phone",
                    hint: "Enter your phone number",
                    keyboard: .phonePad,
                    isSecure: false
                )
                .focused($focusedField, equals: .phone)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .company
                }

                PrimaryTextField(
                    text: $presenter.companyText,
                    title: "Company",
                    hint: "Enter your company name",
                    keyboard: .default,
                    isSecure: false
                )
                .focused($focusedField, equals: .company)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .newPassword
                }

                PrimaryTextField(
                    text: $presenter.passText,
                    title: "Password",
                    hint: "Enter your password",
                    keyboard: .asciiCapable,
                    isSecure: true
                )
                .focused($focusedField, equals: .newPassword)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }

                PrimaryTextField(
                    text: $presenter.confirmText,
                    title: "Confirm Pass",
                    hint: "Confirm your password",
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
                            if await presenter.register() {
                                navigation.navigate(to: .home)
                            }
                        }
                    },
                    label: {
                        Group {
                            if presenter.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Register")
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
                    Text("Already have an account?")
                        .customFont(.medium, 16)
                        .foregroundStyle(.subtitle)

                    Button("Login") {
                        navigation.navigate(to: .login)
                    }
                    .font(.customFont(.medium, 16))
                    .foregroundStyle(.mySecondary)
                }
                .animation(.smooth, value: focusedField)
                .opacity(focusedField != nil ? 0.0 : 1.0)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
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
