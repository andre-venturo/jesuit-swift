//
//  CashReceiptDetailSheet.swift
//  Jesuit
//
//  Penerimaan (cash receipt) detail: status banner, transaction fields, the
//  Detail Lines table and the role/status-gated actions
//  (Ubah / Setujui / Tolak / Hapus).
//

import SwiftUI

struct CashReceiptDetailSheet: View {
    let id: String
    /// Called after a mutation (approve/reject/delete/edit) so the list reloads.
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var presenter: CashReceiptDetailPresenter
    @State private var showApprove = false
    @State private var showReject = false
    @State private var showDeleteConfirm = false
    @State private var showEdit = false

    init(id: String, onChanged: @escaping () -> Void) {
        self.id = id
        self.onChanged = onChanged
        _presenter = State(initialValue: AppDI.shared.cashReceiptDetailPresenter(id: id))
    }

    var body: some View {
        NavigationStack {
            Group {
                if presenter.isLoading {
                    ProgressView().tint(.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = presenter.errorMessage {
                    stateMessage(error, systemImage: "exclamationmark.triangle")
                } else if let detail = presenter.detail {
                    content(detail)
                } else {
                    stateMessage("Detail tidak tersedia.", systemImage: "doc")
                }
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle(presenter.detail?.number ?? "Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
        .task { await presenter.load() }
        .sheet(isPresented: $showEdit) {
            if let detail = presenter.detail {
                CreateReceiptSheet(editing: detail, onCreated: {
                    onChanged()
                    Task { await presenter.load() }
                })
            }
        }
        .alert("Setujui transaksi?", isPresented: $showApprove) {
            Button("Batal", role: .cancel) {}
            Button("Setujui") { Task { await act { await presenter.approve(comment: "") } } }
        } message: {
            Text("Transaksi akan diposting ke buku besar.")
        }
        .alert("Tolak transaksi", isPresented: $showReject) {
            TextField("Alasan", text: $rejectReason)
            Button("Batal", role: .cancel) { rejectReason = "" }
            Button("Tolak", role: .destructive) {
                let reason = rejectReason
                rejectReason = ""
                Task { await act { await presenter.reject(reason: reason) } }
            }
        } message: {
            Text("Masukkan alasan penolakan.")
        }
        .alert("Hapus transaksi?", isPresented: $showDeleteConfirm) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) {
                Task {
                    if await presenter.delete() {
                        onChanged()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Tindakan ini tidak dapat dibatalkan.")
        }
    }

    @State private var rejectReason = ""

    // MARK: - Content

    private func content(_ detail: CashReceiptDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusBanner(detail)
                fieldsGrid(detail)
                if !detail.description.isEmpty {
                    field("Deskripsi", detail.description)
                }
                linesSection(detail)
            }
            .padding(20)
            .padding(.bottom, 90)
        }
        .safeAreaInset(edge: .bottom) { actionBar(detail) }
        .overlay {
            if presenter.isWorking {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().tint(.accent)
            }
        }
    }

    private func statusBanner(_ detail: CashReceiptDetail) -> some View {
        HStack(spacing: 12) {
            Image(systemName: bannerIcon(detail.status))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(detail.status.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.status.rawValue)
                    .customFont(.semibold, 16)
                    .foregroundStyle(detail.status.tint)
                if let level = detail.approvalLevel, let total = detail.totalApprovalLevels,
                   detail.status == .pendingApproval {
                    Text("Level \(level) dari \(total)")
                        .customFont(.regular, 13)
                        .foregroundStyle(.subtitle)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(detail.status.tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func bannerIcon(_ status: ReceiptStatus) -> String {
        switch status {
        case .draft:           return "doc"
        case .pendingApproval: return "clock"
        case .approved:        return "checkmark.seal.fill"
        case .rejected:        return "xmark.seal.fill"
        }
    }

    private func fieldsGrid(_ detail: CashReceiptDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                field("No. Transaksi", detail.number)
                field("Tanggal Transaksi", Self.dayFormat(detail.date))
            }
            HStack(alignment: .top, spacing: 16) {
                field("Akun Kas/Bank", detail.cashAccountName, sub: detail.branchName)
                field("Total", detail.total.asRupiah)
            }
            HStack(alignment: .top, spacing: 16) {
                field("Jurnal Terkait", detail.hasJournal ? "Terbentuk" : "—",
                      sub: detail.hasJournal ? nil : "Belum terbentuk")
                field("Terakhir Diperbarui", Self.dateTimeFormat(detail.updatedAt))
            }
        }
    }

    private func linesSection(_ detail: CashReceiptDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detail Lines (\(detail.lines.count))")
                .customFont(.semibold, 16)
                .foregroundStyle(.title)

            VStack(spacing: 0) {
                ForEach(Array(detail.lines.enumerated()), id: \.element.id) { index, line in
                    lineRow(line)
                    if index < detail.lines.count - 1 {
                        Divider().opacity(0.4).padding(.leading, 14)
                    }
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func lineRow(_ line: CashReceiptLine) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(line.lineNumber)")
                .customFont(.medium, 14)
                .foregroundStyle(.subtitle)
                .frame(width: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(line.accountName)
                        .customFont(.medium, 15)
                        .foregroundStyle(.title)
                        .lineLimit(1)
                    if line.isPinned {
                        Text("Utama")
                            .customFont(.medium, 11)
                            .foregroundStyle(.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
                if !line.description.isEmpty {
                    Text(line.description)
                        .customFont(.regular, 13)
                        .foregroundStyle(.subtitle)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Text(line.amount.asRupiah)
                .customFont(.semibold, 15)
                .foregroundStyle(.title)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(14)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionBar(_ detail: CashReceiptDetail) -> some View {
        let buttons = visibleActions
        if !buttons.isEmpty {
            HStack(spacing: 10) {
                ForEach(buttons, id: \.self) { action in
                    actionButton(action)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private enum Action: Hashable { case ubah, setujui, tolak, hapus }

    private var visibleActions: [Action] {
        var actions: [Action] = []
        if presenter.canEdit { actions.append(.ubah) }
        if presenter.canApproveOrReject { actions.append(.setujui); actions.append(.tolak) }
        if presenter.canDelete { actions.append(.hapus) }
        return actions
    }

    @ViewBuilder
    private func actionButton(_ action: Action) -> some View {
        switch action {
        case .ubah:
            barButton("Ubah", systemImage: "pencil", tint: .title, filled: false) { showEdit = true }
        case .setujui:
            barButton("Setujui", systemImage: "checkmark", tint: .income, filled: true) { showApprove = true }
        case .tolak:
            barButton("Tolak", systemImage: "xmark", tint: .orange, filled: false) { showReject = true }
        case .hapus:
            barButton("Hapus", systemImage: "trash", tint: .expense, filled: false) { showDeleteConfirm = true }
        }
    }

    private func barButton(
        _ title: String, systemImage: String, tint: Color, filled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
                Text(title).customFont(.semibold, 15)
            }
            .foregroundStyle(filled ? .white : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(filled ? tint : tint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(presenter.isWorking)
    }

    /// Runs an action and reloads the list on success.
    private func act(_ op: @escaping () async -> Bool) async {
        if await op() { onChanged() }
    }

    // MARK: - Helpers

    private func field(_ label: String, _ value: String, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .customFont(.regular, 13)
                .foregroundStyle(.subtitle)
            Text(value)
                .customFont(.semibold, 16)
                .foregroundStyle(.title)
                .fixedSize(horizontal: false, vertical: true)
            if let sub {
                Text(sub)
                    .customFont(.regular, 12)
                    .foregroundStyle(.subtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stateMessage(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.subtitle)
            Text(text)
                .customFont(.medium, 15)
                .foregroundStyle(.subtitle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private static func dayFormat(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    private static func dateTimeFormat(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM yyyy, HH.mm"
        return f.string(from: date)
    }
}
