//
//  CreateAccountSheet.swift
//  Jesuit
//
//  "Akun Baru" / "Ubah Akun" — create/edit form for a chart-of-accounts entry.
//  Pushed from MasterAkunScreen's "+" (create) or a list row (edit — Kontak
//  pattern, no detail page). Edit mode carries the delete button.
//

import SwiftUI

struct CreateAccountSheet: View {
    let presenter: MasterAkunPresenter
    let onSaved: () -> Void
    /// When non-nil the form edits this account (PUT) instead of creating.
    private let editTarget: ChartAccount?

    @Injected private var session: AuthSession
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    /// Create mode.
    init(presenter: MasterAkunPresenter, onSaved: @escaping () -> Void) {
        self.presenter = presenter
        self.onSaved = onSaved
        self.editTarget = nil
    }

    /// Edit mode (seeds the form from `editing`).
    init(presenter: MasterAkunPresenter, editing account: ChartAccount, onSaved: @escaping () -> Void) {
        self.presenter = presenter
        self.onSaved = onSaved
        self.editTarget = account
    }

    private var isEditing: Bool { editTarget != nil }

    private var form: MasterAkunPresenter.CreateForm { presenter.form }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FormCard("Detail Akun") {
                    FormFieldRow(label: "Nama", required: true, text: bind(\.name),
                                 placeholder: "Nama akun")
                    FormFieldRow(label: "Kode", text: bind(\.code), placeholder: "1-10001")
                    typePicker
                    if !subTypeOptions.isEmpty {
                        FormPickerRow(
                            label: "Sub Tipe",
                            options: subTypeOptions,
                            selectedId: form.subType,
                            sheetTitle: "Sub Tipe",
                            searchPrompt: "Cari sub tipe…",
                            onSelect: { form.subType = $0 }
                        )
                    }
                    FormPickerRow(
                        label: "Akun Induk",
                        options: parentOptions,
                        selectedId: form.parentId,
                        sheetTitle: "Akun Induk",
                        searchPrompt: "Cari akun…",
                        onSelect: { form.parentId = $0 }
                    )
                    FormFieldRow(label: "Mata Uang", text: bind(\.currencyCode),
                                 placeholder: "IDR", showDivider: false)
                }

                FormCard("Deskripsi") {
                    FormTextAreaRow(label: "Deskripsi", text: bind(\.descriptionText),
                                    placeholder: "Catatan akun (opsional)", showDivider: false)
                }

                FormCard {
                    FormToggleRow(label: "Aktif", isOn: bind(\.isActive))
                }

                if let error = form.errorMessage ?? presenter.deleteError {
                    Text(error)
                        .customFont(.medium, Typography.callout)
                        .foregroundStyle(.expense)
                }

                saveButton

                if isEditing && session.can(Permission.accountDelete) {
                    deleteButton
                }
            }
            .padding(20)
        }
        .background(Color.background1.ignoresSafeArea())
        .navigationTitle(isEditing ? "Ubah Akun" : "Akun Baru")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Hapus Akun", isPresented: $showDeleteConfirm) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) {
                Task {
                    if let editTarget, await presenter.deleteAccount(id: editTarget.id) {
                        onSaved()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Hapus \(editTarget?.name ?? "akun ini")? Akun yang sudah dipakai transaksi tidak dapat dihapus.")
        }
        .task {
            if let editTarget {
                presenter.startEditing(editTarget)
            } else {
                presenter.startCreate()
            }
        }
    }

    // MARK: - Pickers

    /// Type is locked while editing (a single locked option — changing the type
    /// of a posted account would corrupt reports; the server likely rejects it).
    private var typePicker: some View {
        FormPickerRow(
            label: "Tipe Akun", required: true,
            options: typeOptions,
            selectedId: form.typeId.isEmpty ? nil : form.typeId,
            placeholder: "Pilih tipe",
            sheetTitle: "Tipe Akun",
            onSelect: { form.typeId = $0 }
        )
    }

    private var typeOptions: [SelectionOption] {
        if isEditing {
            // Single option == locked row (FormPickerRow hides the chevron/sheet).
            let title = AccountType(rawValue: form.typeId)?.label
                ?? (form.typeId.isEmpty ? "—" : form.typeId)
            return [SelectionOption(id: form.typeId, title: title)]
        }
        return AccountType.allCases.map { SelectionOption(id: $0.rawValue, title: $0.label) }
    }

    /// The prepended "Tanpa …" row keeps options.count >= 2, which prevents
    /// FormPickerRow's auto-select-single-option from silently applying a value.
    /// Titles are the server's display labels; the raw id is what gets sent.
    private var subTypeOptions: [SelectionOption] {
        let known = presenter.subTypeOptions
        guard !known.isEmpty else { return [] }
        return [SelectionOption(id: "", title: "Tanpa sub tipe")]
            + known.map { SelectionOption(id: $0.id, title: $0.label) }
    }

    private var parentOptions: [SelectionOption] {
        let headers = presenter.parentOptions(for: AccountType(rawValue: form.typeId))
            .filter { $0.id != form.editId }  // an account can't parent itself
        var options = [SelectionOption(id: "", title: "Tanpa induk")]
            + headers.map { SelectionOption(id: $0.id, title: $0.name, subtitle: $0.code) }
        if !form.parentId.isEmpty && !headers.contains(where: { $0.id == form.parentId }) {
            options.append(SelectionOption(
                id: form.parentId,
                title: presenter.accountName(for: form.parentId) ?? "Akun induk saat ini"
            ))
        }
        return options
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Task {
                if await presenter.saveAccount() {
                    onSaved()
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

    // MARK: - Delete

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
                    Text("Hapus Akun")
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
    private func bind(_ keyPath: ReferenceWritableKeyPath<MasterAkunPresenter.CreateForm, String>) -> Binding<String> {
        Binding(get: { form[keyPath: keyPath] }, set: { form[keyPath: keyPath] = $0 })
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<MasterAkunPresenter.CreateForm, Bool>) -> Binding<Bool> {
        Binding(get: { form[keyPath: keyPath] }, set: { form[keyPath: keyPath] = $0 })
    }
}
