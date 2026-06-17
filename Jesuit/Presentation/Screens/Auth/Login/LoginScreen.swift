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

            Text("Selamat Datang!")
                .customFont(.bold, 30)
                .foregroundStyle(.title)

            Text("Masuk untuk melanjutkan")
                .customFont(.medium, 18)
                .foregroundStyle(.subtitle)

            PrimaryTextField(
                text: $presenter.emailText,
                title: "Email atau Username",
                hint: "Masukkan email atau username",
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
                title: "Kata Sandi",
                hint: "Masukkan kata sandi",
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
                            Text("Masuk")
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
                Text("Belum punya akun?")
                    .customFont(.medium, 16)
                    .foregroundStyle(.subtitle)

                Button("Daftar") {
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
