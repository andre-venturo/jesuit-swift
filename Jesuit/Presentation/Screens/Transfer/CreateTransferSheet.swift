//
//  CreateTransferSheet.swift
//  Jesuit
//
//  "Transfer Dana Baru" — create/edit form for a fund transfer. Header (Tanggal +
//  Deskripsi), a Sumber (from account/branch) and Tujuan (to account/branch)
//  section, the amount (with an FX leg when the two accounts differ in currency),
//  and attachments. Saves as draft (POST /fund-transfers) or submitted
//  (POST /fund-transfers/submit).
//

import SwiftUI

struct CreateTransferSheet: View {
    @State private var presenter: TransferPresenter
    let onCreated: () -> Void
    private let editTarget: FundTransferDetail?

    @Environment(\.dismiss) private var dismiss
    @State private var saveWarning: String?

    /// Create mode: caller supplies the shared presenter (its `form` is reset).
    init(presenter: TransferPresenter, onCreated: @escaping () -> Void) {
        _presenter = State(initialValue: presenter)
        self.onCreated = onCreated
        self.editTarget = nil
    }

    /// Edit mode: builds its own presenter and seeds the form from `editing`.
    init(editing detail: FundTransferDetail, onCreated: @escaping () -> Void) {
        _presenter = State(initialValue: AppDI.shared.resolver(TransferPresenter.self))
        self.onCreated = onCreated
        self.editTarget = detail
    }

    private var isEditing: Bool { editTarget != nil }
    private var form: TransferPresenter.CreateForm { presenter.form }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    detailCard
                    sourceCard
                    destinationCard

                    if form.sameAccount {
                        validationNote("Akun tujuan harus berbeda dari akun sumber.")
                    }

                    amountCard

                    AttachmentsField(
                        attachments: Binding(get: { form.attachments }, set: { form.attachments = $0 }),
                        existing: form.existingAttachments
                    )

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
            .navigationTitle(isEditing ? "Ubah Transfer Dana" : "Transfer Dana Baru")
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
        .alert("Sebagian lampiran gagal", isPresented: Binding(get: { saveWarning != nil }, set: { if !$0 { saveWarning = nil } })) {
            Button("OK") { saveWarning = nil; dismiss() }
        } message: {
            Text(saveWarning ?? "")
        }
    }

    // MARK: - Sections

    private var detailCard: some View {
        FormCard("Detail Transfer") {
            FormDateRow(label: "Tanggal", required: true,
                        date: Binding(get: { form.date }, set: { form.date = $0 }))
            FormTextAreaRow(
                label: "Deskripsi",
                text: Binding(get: { form.description }, set: { form.description = $0 }),
                placeholder: "Deskripsi transfer (opsional)",
                showDivider: false
            )
        }
    }

    private var sourceCard: some View {
        FormCard("Sumber Dana") {
            FormPickerRow(
                label: "Dari Akun", required: true,
                options: form.accounts.map(SelectionOption.init(account:)),
                selectedId: form.fromAccountId,
                placeholder: "Pilih akun",
                sheetTitle: "Pilih Akun Sumber",
                searchPrompt: "Cari akun…",
                onSelect: { id in
                    form.fromAccountId = id
                    Task { await presenter.onAccountChanged() }
                }
            )
            FormPickerRow(
                label: "Dari Cabang", required: true,
                options: form.branches.map { SelectionOption(id: $0.id, title: $0.name) },
                selectedId: form.fromBranchId,
                placeholder: "Pilih cabang",
                sheetTitle: "Pilih Cabang",
                searchPrompt: "Cari cabang…",
                showDivider: false,
                onSelect: { form.fromBranchId = $0 }
            )
        }
    }

    private var destinationCard: some View {
        FormCard("Tujuan") {
            FormPickerRow(
                label: "Ke Akun", required: true,
                options: form.accounts.map(SelectionOption.init(account:)),
                selectedId: form.toAccountId,
                placeholder: "Pilih akun",
                sheetTitle: "Pilih Akun Tujuan",
                searchPrompt: "Cari akun…",
                onSelect: { id in
                    form.toAccountId = id
                    Task { await presenter.onAccountChanged() }
                }
            )
            FormPickerRow(
                label: "Ke Cabang", required: true,
                options: form.branches.map { SelectionOption(id: $0.id, title: $0.name) },
                selectedId: form.toBranchId,
                placeholder: "Pilih cabang",
                sheetTitle: "Pilih Cabang",
                searchPrompt: "Cari cabang…",
                showDivider: false,
                onSelect: { form.toBranchId = $0 }
            )
        }
    }

    // MARK: - Amount (with optional FX leg)

    @ViewBuilder
    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormCard("Jumlah") {
                if form.isForeign {
                    FormCurrencyRow(
                        label: "Kurs (1 \(form.foreignCurrency) = Rp)", required: true,
                        digits: Binding(
                            get: { form.exchangeRate > 0 ? String(Int(form.exchangeRate)) : "" },
                            set: { form.exchangeRate = Double($0) ?? 0; form.recomputeIDRFromForeign() }
                        )
                    )
                    FormFieldRow(
                        label: "Jumlah (\(form.foreignCurrency))", required: true,
                        text: Binding(
                            get: { form.foreignAmountText },
                            set: { form.foreignAmountText = $0; form.recomputeIDRFromForeign() }
                        ),
                        placeholder: "0",
                        keyboard: .decimalPad
                    )
                    FormCurrencyRow(
                        label: "Jumlah (Rp)", required: true,
                        digits: Binding(
                            get: { form.amountText },
                            set: { form.amountText = $0; form.recomputeForeignFromIDR() }
                        ),
                        showDivider: false
                    )
                } else {
                    FormCurrencyRow(
                        label: "Jumlah (IDR)", required: true,
                        digits: Binding(get: { form.amountText }, set: { form.amountText = $0 }),
                        showDivider: false
                    )
                }
            }
            if form.isForeign {
                Text("Kurs diambil otomatis, boleh ditimpa manual. Yang disimpan adalah Rp.")
                    .customFont(.regular, Typography.caption)
                    .foregroundStyle(.subtitle)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        Group {
            if isEditing {
                Button { save(submit: true) } label: {
                    actionLabel("Simpan Perubahan", filled: true)
                }
            } else {
                HStack(spacing: 12) {
                    Button { save(submit: false) } label: {
                        actionLabel("Simpan Draft", filled: false)
                    }
                    Button { save(submit: true) } label: {
                        actionLabel("Simpan & Submit", filled: true)
                    }
                }
            }
        }
        .disabled(!form.canSave)
        .opacity(form.canSave ? 1 : 0.5)
        .overlay { if form.isSaving { ProgressView().tint(.accent) } }
        .padding(.top, 8)
    }

    private func save(submit: Bool) {
        Task {
            if await presenter.save(submit: submit) {
                onCreated()
                if let warning = presenter.attachmentWarning {
                    saveWarning = warning
                } else {
                    dismiss()
                }
            }
        }
    }

    private func validationNote(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
            Text(text)
                .customFont(.medium, Typography.subhead)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.expense)
        .padding(.horizontal, 4)
    }

    private func actionLabel(_ title: String, filled: Bool) -> some View {
        Text(title)
            .customFont(.medium, Typography.body)
            .foregroundStyle(filled ? .white : Color.title)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(filled ? Color.accentColor : Color.textFieldBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
