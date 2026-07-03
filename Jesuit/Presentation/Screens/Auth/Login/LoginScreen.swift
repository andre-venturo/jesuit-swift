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
            Spacer(minLength: 0)

            // Logo with a soft accent glow for depth on the dark background.
            Image(.imageLogin)
                .resizable()
                .scaledToFit()
                .frame(width: 64)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.25))
                        .frame(width: 140, height: 140)
                        .blur(radius: 40)
                )
                .padding(.bottom, 16)
                .animation(.smooth, value: focusedField)
                .opacity(focusedField != nil ? 0.0 : 1.0)

            VStack(spacing: 6) {
                Text("Selamat Datang!")
                    .customFont(.bold, Typography.display)
                    .foregroundStyle(.title)

                Text("Masuk untuk melanjutkan")
                    .customFont(.medium, Typography.headline)
                    .foregroundStyle(.subtitle)
            }
            .padding(.bottom, 16)

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
                    .customFont(.medium, Typography.callout)
                    .foregroundStyle(.expense)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
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
                                    .font(.customFont(.medium, Typography.headline))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)   // matches the Face ID square beside it
                        .background(.accent)
                        .cornerRadius(12)
                    }
                )
                .disabled(presenter.isLoading)

                // Biometric re-entry after a soft sign-out: restores the kept session
                // behind a Face ID scan — no password typed, no password stored.
                if presenter.canBiometricLogin {
                    Button {
                        focusedField = nil
                        Task {
                            if await presenter.biometricLogin() {
                                navigation.navigate(to: .home)
                            }
                        }
                    } label: {
                        Image(systemName: BiometricAuth.systemImage)
                            .font(.system(size: 20))
                            .foregroundStyle(.accent)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.accentColor, lineWidth: 1.5)
                            )
                    }
                    .disabled(presenter.isLoading)
                    .accessibilityLabel("Masuk dengan \(BiometricAuth.label)")
                }
            }
            .padding(.top, 12)

            Spacer(minLength: 0)

            // Register link pinned to the bottom, out of the form's visual group.
            HStack(spacing: 4) {
                Text("Belum punya akun?")
                    .customFont(.medium, Typography.body)
                    .foregroundStyle(.subtitle)

                Button("Daftar") {
                    navigation.navigate(to: .register)
                }
                .font(.customFont(.semibold, Typography.body))
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
        .task { await presenter.checkBiometricLogin() }
        .hotReloadable()
    }
}
