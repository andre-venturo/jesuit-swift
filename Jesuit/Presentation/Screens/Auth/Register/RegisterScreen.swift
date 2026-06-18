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
                Text("Mulai Sekarang")
                    .customFont(.bold, Typography.display)
                    .foregroundStyle(.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.smooth, value: focusedField)
                    .opacity(focusedField != nil ? 0.0 : 1.0)

                HStack(spacing: 6) {
                    Text("Sudah punya akun?")
                        .customFont(.medium, Typography.body)
                        .foregroundStyle(.subtitle)
                    Button("Masuk") {
                        navigation.navigate(to: .login)
                    }
                    .font(.customFont(.medium, Typography.body))
                    .foregroundStyle(.mySecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 20)
                .animation(.smooth, value: focusedField)
                .opacity(focusedField != nil ? 0.0 : 1.0)

                PrimaryTextField(
                    text: $presenter.nameText,
                    title: "Nama lengkap",
                    hint: "Masukkan nama lengkap",
                    keyboard: .default,
                    isSecure: false
                )
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .email
                }

                PrimaryTextField(
                    text: $presenter.emailText,
                    title: "Alamat email",
                    hint: "Masukkan alamat email",
                    keyboard: .emailAddress,
                    isSecure: false
                )
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .username
                }

                PrimaryTextField(
                    text: $presenter.usernameText,
                    title: "Username",
                    hint: "Pilih username",
                    keyboard: .default,
                    isSecure: false
                )
                .focused($focusedField, equals: .username)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .phone
                }

                PrimaryTextField(
                    text: $presenter.phoneText,
                    title: "Nomor telepon (opsional)",
                    hint: "Masukkan nomor telepon",
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
                    title: "Nama perusahaan",
                    hint: "Masukkan nama perusahaan",
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
                    title: "Kata sandi",
                    hint: "Minimal 6 karakter",
                    keyboard: .asciiCapable,
                    isSecure: true
                )
                .focused($focusedField, equals: .newPassword)
                .submitLabel(.done)

                if let error = presenter.errorMessage {
                    Text(error)
                        .customFont(.medium, Typography.callout)
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
                                Text("Buat akun")
                                    .font(.customFont(.medium, Typography.title2))
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

                Text("Dengan mendaftar, saya menyetujui Syarat layanan dan Kebijakan privasi.")
                    .customFont(.regular, Typography.callout)
                    .foregroundStyle(.subtitle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
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
