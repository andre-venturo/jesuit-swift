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
    /// When non-nil the sheet edits this contact (PUT) instead of creating.
    private let editTarget: Contact?

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    /// Create mode (shared list presenter; its form is reset on appear).
    init(presenter: ContactPresenter, onCreated: @escaping () -> Void) {
        self.presenter = presenter
        self.onCreated = onCreated
        self.editTarget = nil
    }

    /// Edit mode (own presenter; seeds the form from `editing`).
    init(editing contact: Contact, onCreated: @escaping () -> Void) {
        self.presenter = AppDI.shared.resolver(ContactPresenter.self)
        self.onCreated = onCreated
        self.editTarget = contact
    }

    private var isEditing: Bool { editTarget != nil }

    private var form: ContactPresenter.CreateForm { presenter.form }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormCard("Detail Kontak") {
                        FormFieldRow(label: "Nama", required: true, text: bind(\.name),
                                     placeholder: "Nama kontak")
                        FormPickerRow(
                            label: "Kategori", required: true,
                            options: form.categories.map { SelectionOption(id: $0.id, title: $0.name) },
                            selectedId: form.categoryId.isEmpty ? nil : form.categoryId,
                            placeholder: "Pilih kategori",
                            sheetTitle: "Kategori",
                            searchPrompt: "Cari kategori…",
                            onSelect: { form.categoryId = $0 }
                        )
                        FormFieldRow(label: "Email", text: bind(\.email),
                                     placeholder: "name@email.com", keyboard: .emailAddress)
                        FormFieldRow(label: "Telepon", text: bind(\.phone),
                                     placeholder: "08xxxxxxxxxx", keyboard: .phonePad)
                        FormFieldRow(label: "Alamat", text: bind(\.address),
                                     placeholder: "Alamat", showDivider: false)
                    }

                    FormCard("Narahubung (PIC)") {
                        FormFieldRow(label: "Nama PIC", text: bind(\.picName), placeholder: "Nama PIC")
                        FormFieldRow(label: "Jabatan PIC", text: bind(\.picPosition),
                                     placeholder: "Jabatan", showDivider: false)
                    }

                    FormCard {
                        FormToggleRow(label: "Aktif", isOn: bind(\.isActive))
                    }

                    if let error = form.errorMessage {
                        Text(error)
                            .customFont(.medium, Typography.callout)
                            .foregroundStyle(.expense)
                    }

                    saveButton

                    if isEditing {
                        deleteButton
                    }
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle(isEditing ? "Ubah Kontak" : "Kontak Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.subtitle)
                }
            }
            .alert("Hapus Kontak", isPresented: $showDeleteConfirm) {
                Button("Batal", role: .cancel) {}
                Button("Hapus", role: .destructive) {
                    Task {
                        if let editTarget, await presenter.deleteContact(id: editTarget.id) {
                            onCreated()
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Hapus \(editTarget?.name ?? "kontak ini")? Tindakan ini tidak dapat dibatalkan.")
            }
        }
        .task {
            if let editTarget {
                presenter.startEditing(editTarget)
            } else {
                presenter.startCreate()
            }
            await presenter.loadCategories()
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Task {
                if await presenter.saveContact() {
                    onCreated()
                    dismiss()
                }
            }
        } label: {
            Group {
                if presenter.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(isEditing ? "Simpan Perubahan" : "Simpan")
                        .customFont(.semibold, Typography.body)
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

    private var isDeleting: Bool {
        guard let editTarget else { return false }
        return presenter.deletingId == editTarget.id
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Group {
                if isDeleting {
                    ProgressView().tint(.expense)
                } else {
                    Text("Hapus Kontak")
                        .customFont(.semibold, Typography.body)
                        .foregroundStyle(.expense)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.expense.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isDeleting || presenter.isSaving)
    }

    // MARK: - Helpers

    /// Two-way binding into the observable form by key path.
    private func bind(_ keyPath: ReferenceWritableKeyPath<ContactPresenter.CreateForm, String>) -> Binding<String> {
        Binding(get: { form[keyPath: keyPath] }, set: { form[keyPath: keyPath] = $0 })
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<ContactPresenter.CreateForm, Bool>) -> Binding<Bool> {
        Binding(get: { form[keyPath: keyPath] }, set: { form[keyPath: keyPath] = $0 })
    }
}
