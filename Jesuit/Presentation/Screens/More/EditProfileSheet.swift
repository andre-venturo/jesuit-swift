//
//  EditProfileSheet.swift
//  Jesuit
//
//  "Ubah Profil" form presented from the More tab. Edits the signed-in user's
//  full name and phone via `PUT /users/me`.
//

import SwiftUI

struct EditProfileSheet: View {
    @State private var presenter = AppDI.shared.resolver(EditProfilePresenter.self)
    @FocusState private var focusedField: AppField?
    @Environment(\.dismiss) private var dismiss

    /// Called after a successful save so the caller can show confirmation.
    var onSuccess: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    avatar

                    readOnlyField(title: "Email", value: presenter.email)
                    readOnlyField(title: "Username", value: presenter.username)

                    PrimaryTextField(
                        text: $presenter.fullName,
                        title: "Nama Lengkap",
                        hint: "Masukkan nama lengkap",
                        keyboard: .default,
                        isSecure: false
                    )
                    .focused($focusedField, equals: .name)

                    PrimaryTextField(
                        text: $presenter.phone,
                        title: "Nomor Telepon",
                        hint: "Masukkan nomor telepon",
                        keyboard: .phonePad,
                        isSecure: false
                    )
                    .focused($focusedField, equals: .phone)

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
            .navigationTitle("Ubah Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.subtitle)
                }
            }
        }
        .onAppear { presenter.prefill() }
        .hotReloadable()
    }

    /// Avatar placeholder with initials. (The backend has no photo field yet, so
    /// upload is intentionally omitted — matches the web's avatar without a
    /// dead upload control.)
    private var avatar: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 72, height: 72)
                .overlay(
                    Text(presenter.initials)
                        .customFont(.bold, 24)
                        .foregroundStyle(.accent)
                )
            Spacer()
        }
    }

    /// A disabled, read-only field with an "ask an admin" hint, mirroring the
    /// web form's locked Email / Username inputs.
    private func readOnlyField(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .customFont(.medium, 16)
                .foregroundStyle(.title)
            HStack {
                Text(value)
                    .customFont(.regular, 16)
                    .foregroundStyle(.subtitle)
                Spacer()
            }
            .coreTextFieldStyle()
            .opacity(0.6)
            Text("Hubungi admin untuk mengubah.")
                .customFont(.regular, 13)
                .foregroundStyle(.subtitle)
        }
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
