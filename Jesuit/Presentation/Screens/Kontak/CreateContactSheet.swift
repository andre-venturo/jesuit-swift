//
//  CreateContactSheet.swift
//  Jesuit
//
//  "Kontak Baru" — create-contact form presented from the Kontak "+" button.
//  Posts to POST /finance/v1/contacts.
//

import SwiftUI

struct CreateContactSheet: View {
    let presenter: ContactPresenter
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var form: ContactPresenter.CreateForm { presenter.form }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("Nama", text: bind(\.name), hint: "Nama kontak")
                    categorySection
                    field("Email", text: bind(\.email), hint: "name@email.com", keyboard: .emailAddress)
                    field("Telepon", text: bind(\.phone), hint: "08xxxxxxxxxx", keyboard: .phonePad)
                    field("Alamat", text: bind(\.address), hint: "Alamat")
                    field("Nama PIC", text: bind(\.picName), hint: "Nama PIC")
                    field("Jabatan PIC", text: bind(\.picPosition), hint: "Jabatan")

                    Toggle(isOn: bind(\.isActive)) {
                        Text("Aktif")
                            .customFont(.medium, 15)
                            .foregroundStyle(.title)
                    }
                    .tint(.accent)

                    if let error = form.errorMessage {
                        Text(error)
                            .customFont(.medium, 14)
                            .foregroundStyle(.expense)
                    }

                    saveButton
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Kontak Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.subtitle)
                }
            }
        }
        .task { await presenter.loadCategories() }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Kategori")
            Menu {
                ForEach(form.categories) { category in
                    Button(category.name) { form.categoryId = category.id }
                }
            } label: {
                HStack {
                    Text(form.categoryName)
                        .customFont(.regular, 16)
                        .foregroundStyle(form.categoryId.isEmpty ? .subtitle : .title)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.subtitle)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.textFieldBG)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Task {
                if await presenter.createContact() {
                    onCreated()
                    dismiss()
                }
            }
        } label: {
            Group {
                if presenter.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Simpan")
                        .customFont(.semibold, 16)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(form.isValid ? Color.accentColor : Color.accentColor.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!form.isValid || presenter.isSaving)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    /// Two-way binding into the observable form by key path.
    private func bind(_ keyPath: ReferenceWritableKeyPath<ContactPresenter.CreateForm, String>) -> Binding<String> {
        Binding(get: { form[keyPath: keyPath] }, set: { form[keyPath: keyPath] = $0 })
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<ContactPresenter.CreateForm, Bool>) -> Binding<Bool> {
        Binding(get: { form[keyPath: keyPath] }, set: { form[keyPath: keyPath] = $0 })
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        hint: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            TextField("", text: text, prompt: Text(hint).foregroundStyle(Color.subtitle))
                .font(.customFont(.regular, 16))
                .foregroundStyle(Color.title)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.textFieldBG)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .customFont(.medium, 15)
            .foregroundStyle(.subtitle)
    }
}
