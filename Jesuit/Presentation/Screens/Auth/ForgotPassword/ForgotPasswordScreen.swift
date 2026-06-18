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

    var text = "Masukkan alamat email yang terhubung dengan akun Anda "
    var text1 = "dan kami akan mengirimkan tautan untuk mengatur ulang kata sandi."

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Lupa Kata Sandi")
                .customFont(.bold, Typography.largeTitle)
                .foregroundStyle(.title)
                .padding(.top, 19)

            Text(text + text1)
                .customFont(.medium, Typography.headline)
                .foregroundStyle(.subtitle)
                .animation(.smooth, value: focusedField)
                
            PrimaryTextField(
                text: $presenter.emailText,
                title: "Alamat Email",
                hint: "Masukkan email Anda",
                keyboard: .emailAddress,
                isSecure: false
            )
            .focused($focusedField, equals: .email)
            .padding(.top, 30)

            Spacer()
            Button(
                action: { navigation.popTo(root: .home) },
                label: {
                    Text("Kirim Tautan Reset")
                        .font(.customFont(.medium, Typography.title2))
                        .foregroundStyle(.white)
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.accent)
            .cornerRadius(12)

            Button("Kembali ke Masuk") {
                navigation.pop()
            }
            .font(.customFont(.medium, Typography.body))
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
