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

    var text = "Kata sandi baru Anda minimal 8 karakter."

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Perbarui Kata Sandi")
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
                title: "Kata Sandi Lama",
                hint: "Masukkan kata sandi lama",
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
                title: "Kata Sandi Baru",
                hint: "Masukkan kata sandi baru",
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
                title: "Konfirmasi Kata Sandi Baru",
                hint: "Ulangi kata sandi baru",
                keyboard: .asciiCapable,
                isSecure: true
            )
            .focused($focusedField, equals: .confirmPassword)
            Spacer()
            Button(
                action: { navigation.pop() },
                label: {
                    Text("Perbarui Kata Sandi")
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
