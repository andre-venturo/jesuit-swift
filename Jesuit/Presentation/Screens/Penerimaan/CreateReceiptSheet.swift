//
//  CreateReceiptSheet.swift
//  Jesuit
//
//  "Penerimaan Kas Baru" — create-receipt form presented from the Penerimaan
//  "+" button. Header (Tanggal + Akun Kas/Bank) plus a repeatable "Detail Baris"
//  table; saves as draft (POST /cash-transactions) or submitted
//  (POST /cash-transactions/submit), transaction_type=receipt.
//

import SwiftUI

struct CreateReceiptSheet: View {
    let presenter: PenerimaanPresenter
    let onCreated: () -> Void
    /// When non-nil the sheet edits this transaction (PUT) instead of creating.
    private let editTarget: CashReceiptDetail?

    @Environment(\.dismiss) private var dismiss
    @State private var editing: LineEdit?

    /// Create mode: caller supplies the shared presenter (its `form` is reset).
    init(presenter: PenerimaanPresenter, onCreated: @escaping () -> Void) {
        self.presenter = presenter
        self.onCreated = onCreated
        self.editTarget = nil
    }

    /// Edit mode: builds its own presenter and seeds the form from `editing`.
    init(editing detail: CashReceiptDetail, onCreated: @escaping () -> Void) {
        self.presenter = AppDI.shared.resolver(PenerimaanPresenter.self)
        self.onCreated = onCreated
        self.editTarget = detail
    }

    private var isEditing: Bool { editTarget != nil }

    private var form: PenerimaanPresenter.CreateForm { presenter.form }

    /// In-flight "Tambah Baris" edit: a detached `draft` plus the `original` row
    /// it replaces (nil for a brand-new line). Committed only on "Tambah".
    private struct LineEdit: Identifiable {
        let id = UUID()
        let draft: PenerimaanPresenter.LineDraft
        let original: PenerimaanPresenter.LineDraft?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    linesSection

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
            .navigationTitle(isEditing ? "Ubah Penerimaan Kas" : "Penerimaan Kas Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.subtitle)
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
        .sheet(item: $editing) { edit in
            EditReceiptLineSheet(
                draft: edit.draft,
                form: form,
                onCommit: { form.commit(edit.draft, replacing: edit.original) }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        FormCard("Detail Transaksi") {
            FormDateRow(label: "Tanggal", required: true,
                        date: Binding(get: { form.date }, set: { form.date = $0 }))
            FormPickerRow(
                label: "Akun Kas/Bank", required: true,
                options: form.accounts.map(SelectionOption.init(account:)),
                selectedId: form.cashAccountId,
                placeholder: "Pilih akun",
                sheetTitle: "Pilih Akun",
                searchPrompt: "Cari akun…",
                showDivider: false,
                onSelect: { form.cashAccountId = $0 }
            )
        }
    }

    // MARK: - Lines

    private var linesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DETAIL BARIS")
                    .customFont(.semibold, Typography.caption)
                    .foregroundStyle(.subtitle)
                Spacer()
                Button {
                    editing = LineEdit(draft: form.newLine(), original: nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Baris")
                    }
                    .font(.customFont(.medium, Typography.callout))
                    .foregroundStyle(.accent)
                }
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                if form.lines.isEmpty {
                    Button { editing = LineEdit(draft: form.newLine(), original: nil) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill").foregroundStyle(.accent)
                            Text("Tambah baris")
                                .customFont(.regular, Typography.body)
                                .foregroundStyle(.accent)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(Array(form.lines.enumerated()), id: \.element.id) { index, line in
                        lineRow(line)
                        FormRowDivider()
                    }
                    totalRow
                }
            }
            .background(Color.textFieldBG)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var totalRow: some View {
        HStack {
            Text("Total")
                .customFont(.bold, Typography.body)
                .foregroundStyle(.title)
            Spacer()
            Text(form.total.asIDR)
                .customFont(.bold, Typography.body)
                .foregroundStyle(.title)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }

    private func lineRow(_ line: PenerimaanPresenter.LineDraft) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                editing = LineEdit(draft: line.copy(), original: line)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(form.accountName(for: line.accountId) ?? "—")
                            .customFont(.medium, Typography.callout)
                            .foregroundStyle(.title)
                            .lineLimit(1)
                        if !line.description.isEmpty {
                            Text(line.description)
                                .customFont(.regular, Typography.subhead)
                                .foregroundStyle(.subtitle)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(line.amount.asIDR)
                        .customFont(.medium, Typography.callout)
                        .foregroundStyle(.title)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { form.removeLine(line) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.expense)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if isEditing {
            Button { save(submit: true) } label: {
                actionLabel("Simpan Perubahan", filled: true)
            }
            .disabled(!form.canSave)
            .opacity(form.canSave ? 1 : 0.5)
            .overlay { if form.isSaving { ProgressView().tint(.accent) } }
            .padding(.top, 8)
        } else {
            HStack(spacing: 12) {
                Button { save(submit: false) } label: {
                    actionLabel("Simpan Draft", filled: false)
                }
                Button { save(submit: true) } label: {
                    actionLabel("Simpan & Submit", filled: true)
                }
            }
            .disabled(!form.canSave)
            .opacity(form.canSave ? 1 : 0.5)
            .overlay { if form.isSaving { ProgressView().tint(.accent) } }
            .padding(.top, 8)
        }
    }

    private func save(submit: Bool) {
        Task {
            if await presenter.save(submit: submit) {
                onCreated()
                dismiss()
            }
        }
    }

    // MARK: - Helpers

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

// MARK: - Add/Edit line ("Tambah Baris")

private struct EditReceiptLineSheet: View {
    @State var draft: PenerimaanPresenter.LineDraft
    let form: PenerimaanPresenter.CreateForm
    let onCommit: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormCard {
                        FormPickerRow(
                            label: "Akun Lawan", required: true,
                            options: form.accounts.map(SelectionOption.init(account:)),
                            selectedId: draft.accountId,
                            placeholder: "Pilih akun",
                            sheetTitle: "Pilih Akun",
                            searchPrompt: "Cari akun…",
                            showDivider: false,
                            onSelect: { draft.accountId = $0 }
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Jumlah (IDR)")
                            .customFont(.medium, Typography.body)
                            .foregroundStyle(.subtitle)
                        CurrencyField(digits: Binding(
                            get: { draft.amountText },
                            set: { draft.amountText = $0 }
                        ))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deskripsi")
                            .customFont(.medium, Typography.body)
                            .foregroundStyle(.subtitle)
                        TextField(
                            "",
                            text: Binding(get: { draft.description }, set: { draft.description = $0 }),
                            prompt: Text("Deskripsi baris").customFont(.regular, Typography.body).foregroundStyle(.subtitle),
                            axis: .vertical
                        )
                        .font(.customFont(.regular, Typography.body))
                        .foregroundStyle(.title)
                        .lineLimit(3, reservesSpace: true)
                        .coreTextFieldStyle()
                    }

                    AttachmentsField(
                        attachments: Binding(
                            get: { draft.attachments },
                            set: { draft.attachments = $0 }
                        ),
                        existing: draft.existingAttachments
                    )
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Tambah Baris")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tambah") {
                        onCommit()
                        dismiss()
                    }
                    .foregroundStyle(draft.isValid ? Color.accentColor : Color.subtitle)
                    .disabled(!draft.isValid)
                }
            }
        }
    }
}
