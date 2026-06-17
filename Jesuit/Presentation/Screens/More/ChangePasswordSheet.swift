//
//  ChangePasswordSheet.swift
//  Jesuit
//
//  "Ubah Password" form presented from the More tab. Collects the current
//  password and a new one (with confirmation) and calls
//  `PUT /users/me/password`.
//

import SwiftUI

struct ChangePasswordSheet: View {
    @State private var presenter = AppDI.shared.resolver(ChangePasswordPresenter.self)
    @FocusState private var focusedField: AppField?
    @Environment(\.dismiss) private var dismiss

    /// Called after a successful change so the caller can show confirmation.
    var onSuccess: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PrimaryTextField(
                        text: $presenter.currentPassword,
                        title: "Kata Sandi Saat Ini",
                        hint: "Masukkan kata sandi saat ini",
                        keyboard: .default,
                        isSecure: true
                    )
                    .focused($focusedField, equals: .oldPassword)

                    PrimaryTextField(
                        text: $presenter.newPassword,
                        title: "Kata Sandi Baru",
                        hint: "Minimal 6 karakter",
                        keyboard: .default,
                        isSecure: true
                    )
                    .focused($focusedField, equals: .newPassword)

                    PrimaryTextField(
                        text: $presenter.confirmPassword,
                        title: "Konfirmasi Kata Sandi Baru",
                        hint: "Ulangi kata sandi baru",
                        keyboard: .default,
                        isSecure: true
                    )
                    .focused($focusedField, equals: .confirmPassword)

                    if let hint = presenter.validationHint {
                        Text(hint)
                            .customFont(.regular, 14)
                            .foregroundStyle(.expense)
                    }

                    if let error = presenter.errorMessage {
                        Text(error)
                            .customFont(.regular, 14)
                            .foregroundStyle(.expense)
                    }

                    saveButton
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Ubah Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.subtitle)
                }
            }
        }
        .hotReloadable()
    }

    private var saveButton: some View {
        Button {
            focusedField = nil
            Task {
                if await presenter.submit() {
                    onSuccess()
                    dismiss()
                }
            }
        } label: {
            Group {
                if presenter.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Simpan")
                        .customFont(.semibold, 18)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(presenter.isValid ? Color.accentColor : Color.accentColor.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!presenter.isValid || presenter.isSaving)
    }
}
