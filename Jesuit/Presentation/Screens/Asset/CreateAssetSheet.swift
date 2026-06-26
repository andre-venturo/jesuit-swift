//
//  CreateAssetSheet.swift
//  Jesuit
//
//  "Aset Baru" — create/edit form for a fixed asset. Photos, the asset info
//  (name, category, branch, location, note) and purchase details (value,
//  quantity, optional purchase date). Saves to /finance/v1/assets. The
//  depreciation fields aren't edited here — they're preserved from the existing
//  asset on edit and defaulted on create.
//

import SwiftUI

struct CreateAssetSheet: View {
    @State private var presenter: AssetPresenter
    let onCreated: () -> Void
    private let editTarget: AssetDetail?

    @Environment(\.dismiss) private var dismiss
    @State private var saveWarning: String?

    /// Create mode: caller supplies the shared presenter (its `form` is reset).
    init(presenter: AssetPresenter, onCreated: @escaping () -> Void) {
        _presenter = State(initialValue: presenter)
        self.onCreated = onCreated
        self.editTarget = nil
    }

    /// Edit mode: builds its own presenter and seeds the form from `editing`.
    init(editing detail: AssetDetail, onCreated: @escaping () -> Void) {
        _presenter = State(initialValue: AppDI.shared.resolver(AssetPresenter.self))
        self.onCreated = onCreated
        self.editTarget = detail
    }

    private var isEditing: Bool { editTarget != nil }
    private var form: AssetPresenter.CreateForm { presenter.form }

    private var categoryOptions: [SelectionOption] {
        form.categories.map { SelectionOption(id: $0.id, title: $0.name, subtitle: $0.codePrefix) }
            + [SelectionOption(id: AssetPresenter.CreateForm.othersOptionId, title: "Lain-lain")]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AttachmentsField(
                        attachments: Binding(get: { form.attachments }, set: { form.attachments = $0 }),
                        existing: form.existingAttachments
                    )

                    infoCard
                    purchaseCard

                    if let error = form.errorMessage {
                        Text(error)
                            .customFont(.medium, Typography.callout)
                            .foregroundStyle(.expense)
                    }

                    actions
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle(isEditing ? "Ubah Aset" : "Aset Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
        .task {
            if let editTarget {
                presenter.startEditing(editTarget)
            } else {
                presenter.startCreate()
            }
            await presenter.loadFormOptions()
        }
        .alert("Sebagian foto gagal", isPresented: Binding(get: { saveWarning != nil }, set: { if !$0 { saveWarning = nil } })) {
            Button("OK") { saveWarning = nil; dismiss() }
        } message: {
            Text(saveWarning ?? "")
        }
    }

    // MARK: - Sections

    private var infoCard: some View {
        FormCard("Informasi Aset") {
            FormFieldRow(
                label: "Nama Aset", required: true,
                text: Binding(get: { form.name }, set: { form.name = $0 }),
                placeholder: "Nama aset"
            )
            FormPickerRow(
                label: "Kategori",
                options: categoryOptions,
                selectedId: form.categoryId ?? AssetPresenter.CreateForm.othersOptionId,
                placeholder: "Lain-lain",
                sheetTitle: "Pilih Kategori",
                searchPrompt: "Cari kategori…",
                onSelect: { id in
                    form.categoryId = (id == AssetPresenter.CreateForm.othersOptionId) ? nil : id
                }
            )
            FormPickerRow(
                label: "Cabang", required: true,
                options: form.branches.map { SelectionOption(id: $0.id, title: $0.name) },
                selectedId: form.branchId,
                placeholder: "Pilih cabang",
                sheetTitle: "Pilih Cabang",
                searchPrompt: "Cari cabang…",
                onSelect: { form.branchId = $0 }
            )
            FormFieldRow(
                label: "Lokasi",
                text: Binding(get: { form.location }, set: { form.location = $0 }),
                placeholder: "Lokasi aset"
            )
            FormTextAreaRow(
                label: "Catatan",
                text: Binding(get: { form.note }, set: { form.note = $0 }),
                placeholder: "Catatan (opsional)",
                showDivider: false
            )
        }
    }

    private var purchaseCard: some View {
        FormCard("Pembelian") {
            FormCurrencyRow(
                label: "Nilai Pembelian", required: true,
                digits: Binding(get: { form.purchaseValueText }, set: { form.purchaseValueText = $0 })
            )
            FormFieldRow(
                label: "Jumlah",
                text: Binding(get: { form.quantityText }, set: { form.quantityText = $0 }),
                placeholder: "1",
                keyboard: .numberPad
            )
            FormToggleRow(
                label: "Set Tanggal Pembelian",
                isOn: Binding(get: { form.hasPurchaseDate }, set: { form.hasPurchaseDate = $0 }),
                showDivider: form.hasPurchaseDate
            )
            if form.hasPurchaseDate {
                FormDateRow(
                    label: "Tanggal Pembelian",
                    date: Binding(get: { form.purchaseDate }, set: { form.purchaseDate = $0 }),
                    showDivider: false
                )
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        Button { save() } label: {
            Text(isEditing ? "Simpan Perubahan" : "Simpan")
                .customFont(.medium, Typography.body)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!form.canSave)
        .opacity(form.canSave ? 1 : 0.5)
        .overlay { if form.isSaving { ProgressView().tint(.accent) } }
        .padding(.top, 8)
    }

    private func save() {
        Task {
            if await presenter.save() {
                onCreated()
                if let warning = presenter.attachmentWarning {
                    saveWarning = warning
                } else {
                    dismiss()
                }
            }
        }
    }
}
