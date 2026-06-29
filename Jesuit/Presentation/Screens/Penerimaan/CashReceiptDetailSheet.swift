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
    /// Which create/edit sheet to present for "Ubah" — receipts and disbursements
    /// share this detail view but have separate edit forms.
    enum Kind { case receipt, disbursement }

    let id: String
    let kind: Kind
    /// Called after a mutation (approve/reject/delete/edit) so the list reloads.
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var presenter: CashReceiptDetailPresenter
    @State private var showApprove = false
    @State private var showReject = false
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    @State private var showMoreOptions = false
    @State private var previewImage: PreviewImage?
    @State private var selectedLine: CashReceiptLine?
    @State private var tab: DetailTab = .detail

    /// Detail-sheet segmented tabs (Zoho's "Expense Details / History").
    private enum DetailTab: String, CaseIterable, Identifiable {
        case detail = "Detail"
        case riwayat = "Riwayat"
        var id: String { rawValue }
    }

    init(id: String, kind: Kind = .receipt, onChanged: @escaping () -> Void) {
        self.id = id
        self.kind = kind
        self.onChanged = onChanged
        _presenter = State(initialValue: AppDI.shared.cashReceiptDetailPresenter(id: id))
    }

    var body: some View {
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
        .toolbar(.hidden, for: .tabBar)
        .task { await presenter.load() }
        .navigationDestination(isPresented: $showEdit) {
            if let detail = presenter.detail {
                switch kind {
                case .receipt:
                    CreateReceiptSheet(editing: detail, onCreated: {
                        onChanged()
                        Task { await presenter.load() }
                    })
                case .disbursement:
                    CreateExpenseSheet(editing: detail, onCreated: {
                        onChanged()
                        Task { await presenter.load() }
                    })
                }
            }
        }
        .navigationDestination(item: $selectedLine) { line in
            CashReceiptLineDetailSheet(
                line: line,
                transactionId: id,
                canEdit: presenter.canEdit,
                onChanged: {
                    onChanged()
                    Task { await presenter.load() }
                }
            )
        }
        .fullScreenCover(item: $previewImage) { ImagePreviewSheet(image: $0) }
        .confirmationDialog("Opsi Lain", isPresented: $showMoreOptions, titleVisibility: .visible) {
            if presenter.canApproveOrReject {
                Button("Setujui") { showApprove = true }
                Button("Tolak", role: .destructive) { showReject = true }
            }
            if presenter.canDelete {
                Button("Hapus", role: .destructive) { showDeleteConfirm = true }
            }
            Button("Batal", role: .cancel) {}
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
                    } else {
                        actionError = presenter.actionErrorMessage
                    }
                }
            }
        } message: {
            Text("Tindakan ini tidak dapat dibatalkan.")
        }
        .alert("Gagal", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    @State private var rejectReason = ""
    @State private var actionError: String?

    // MARK: - Content

    private func content(_ detail: CashReceiptDetail) -> some View {
        VStack(spacing: 16) {
            hero(detail)

            Picker("", selection: $tab) {
                ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            // Paged TabView so the segments can also be swiped; the page
            // selection is bound to the same `tab` as the segmented control.
            TabView(selection: $tab) {
                detailPage(detail).tag(DetailTab.detail)
                riwayatPage.tag(DetailTab.riwayat)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: tab)
        }
        .padding(.top, 20)
        .safeAreaInset(edge: .bottom) { actionBar(detail) }
        .overlay {
            if presenter.isWorking {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().tint(.accent)
            }
        }
        .task(id: tab) {
            if tab == .riwayat { await presenter.loadActivity() }
        }
    }

    private func detailPage(_ detail: CashReceiptDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                infoCard(detail)
                linesSection(detail)
                summaryCard(detail)
                if !detail.description.isEmpty {
                    notesCard(detail.description)
                }
            }
            .padding(20)
            .padding(.bottom, 90)
        }
    }

    private var riwayatPage: some View {
        ScrollView {
            riwayatSection
                .padding(20)
                .padding(.bottom, 90)
        }
    }

    // MARK: - Riwayat (activity log)

    @ViewBuilder
    private var riwayatSection: some View {
        if presenter.isLoadingActivity {
            ProgressView().tint(.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let error = presenter.activityErrorMessage {
            stateMessage(error, systemImage: "exclamationmark.triangle")
        } else if presenter.activity.isEmpty {
            stateMessage("Belum ada riwayat.", systemImage: "clock")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                let entries = presenter.activity
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    activityRow(entry, isLast: index == entries.count - 1)
                }
            }
        }
    }

    private func activityRow(_ entry: ActivityEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(Color.subtitle.opacity(0.3))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 3) {
                if let date = entry.date {
                    Text(Self.dateTimeFormat(date))
                        .customFont(.regular, Typography.subhead)
                        .foregroundStyle(.subtitle)
                }
                Text(entry.title)
                    .customFont(.semibold, Typography.body)
                    .foregroundStyle(.title)
                if !entry.actor.isEmpty {
                    Text(entry.actor)
                        .customFont(.regular, Typography.subhead)
                        .foregroundStyle(.subtitle)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Hero (amount · account · status pill)

    private func hero(_ detail: CashReceiptDetail) -> some View {
        VStack(spacing: 8) {
            Text(detail.total.asCurrency(detail.currencyCode))
                .customFont(.bold, Typography.display)
                .foregroundStyle(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(detail.cashAccountName)
                .customFont(.regular, Typography.body)
                .foregroundStyle(.subtitle)
                .lineLimit(1)

            statusPill(detail)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func statusPill(_ detail: CashReceiptDetail) -> some View {
        let suffix: String = {
            if let level = detail.approvalLevel, let total = detail.totalApprovalLevels,
               detail.status == .pendingApproval {
                return " · Level \(level)/\(total)"
            }
            return ""
        }()
        return HStack(spacing: 6) {
            Image(systemName: bannerIcon(detail.status))
                .font(.system(size: 12, weight: .semibold))
            Text(detail.status.rawValue + suffix)
                .customFont(.semibold, Typography.subhead)
        }
        .foregroundStyle(detail.status.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(detail.status.tint.opacity(0.14))
        .clipShape(Capsule())
    }

    private func bannerIcon(_ status: ReceiptStatus) -> String {
        switch status {
        case .draft:           return "doc"
        case .pendingApproval: return "clock"
        case .approved:        return "checkmark.seal.fill"
        case .rejected:        return "xmark.seal.fill"
        }
    }

    // MARK: - Info card (transaction meta as a grouped list)

    private func infoCard(_ detail: CashReceiptDetail) -> some View {
        VStack(spacing: 0) {
            infoRow("No. Transaksi", detail.number)
            cardDivider
            infoRow("Tanggal Transaksi", Self.dayFormat(detail.date))
            cardDivider
            infoRow("Akun Kas/Bank", detail.cashAccountName)
            if !detail.branchName.isEmpty {
                cardDivider
                infoRow("Cabang", detail.branchName)
            }
            cardDivider
            infoRow("Jurnal Terkait", detail.hasJournal ? "Terbentuk" : "Belum terbentuk")
            cardDivider
            infoRow("Terakhir Diperbarui", Self.dateTimeFormat(detail.updatedAt))
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.subtitle)
            Spacer(minLength: 12)
            Text(value)
                .customFont(.semibold, Typography.callout)
                .foregroundStyle(.title)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var cardDivider: some View {
        Divider().opacity(0.4).padding(.leading, 14)
    }

    // MARK: - Summary (sub total · total)

    private func summaryCard(_ detail: CashReceiptDetail) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sub Total")
                    .customFont(.regular, Typography.callout)
                    .foregroundStyle(.subtitle)
                Spacer()
                Text(detail.total.asCurrency(detail.currencyCode))
                    .customFont(.medium, Typography.callout)
                    .foregroundStyle(.title)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            cardDivider

            HStack {
                Text("Total")
                    .customFont(.semibold, Typography.body)
                    .foregroundStyle(.title)
                Spacer()
                Text(detail.total.asCurrency(detail.currencyCode))
                    .customFont(.bold, Typography.headline)
                    .foregroundStyle(.title)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Notes

    private func notesCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Deskripsi")
                .customFont(.regular, Typography.subhead)
                .foregroundStyle(.subtitle)
            Text(text)
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func linesSection(_ detail: CashReceiptDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detail Baris (\(detail.lines.count))")
                .customFont(.semibold, Typography.body)
                .foregroundStyle(.title)

            VStack(spacing: 0) {
                ForEach(Array(detail.lines.enumerated()), id: \.element.id) { index, line in
                    Button { selectedLine = line } label: {
                        lineRow(line).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(line.lineNumber)")
                    .customFont(.medium, Typography.callout)
                    .foregroundStyle(.subtitle)
                    .frame(width: 18, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(line.accountName)
                            .customFont(.medium, Typography.body)
                            .foregroundStyle(.title)
                            .lineLimit(1)
                        if line.isPinned {
                            Text("Utama")
                                .customFont(.medium, Typography.caption2)
                                .foregroundStyle(.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                    if !line.description.isEmpty {
                        Text(line.description)
                            .customFont(.regular, Typography.subhead)
                            .foregroundStyle(.subtitle)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                Text(line.amount.asCurrency(line.currencyCode))
                    .customFont(.semibold, Typography.body)
                    .foregroundStyle(.title)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.subtitle)
                    .padding(.top, 2)
            }

            if !line.attachments.isEmpty {
                attachmentsRow(line.attachments)
                    .padding(.leading, 28)
            }
        }
        .padding(14)
    }

    /// Horizontal strip of a line's stored attachments as compact icon chips.
    /// Image chips open the in-app preview; other files open in the browser.
    private func attachmentsRow(_ attachments: [CashLineAttachment]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    attachmentChip(attachment)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentChip(_ attachment: CashLineAttachment) -> some View {
        if let preview = PreviewImage(attachment) {
            Button { previewImage = preview } label: { chipBody(attachment) }
                .buttonStyle(.plain)
        } else {
            Link(destination: URL(string: attachment.fileUrl) ?? URL(string: "https://wizhub.id")!) {
                chipBody(attachment)
            }
        }
    }

    private func chipBody(_ attachment: CashLineAttachment) -> some View {
        HStack(spacing: 6) {
            Image(systemName: attachment.isImage ? "photo" : "doc.text")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.accent)
            Text(attachment.fileName)
                .customFont(.medium, Typography.subhead)
                .foregroundStyle(.title)
                .lineLimit(1)
            Text(attachment.sizeLabel)
                .customFont(.regular, Typography.caption2)
                .foregroundStyle(.subtitle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.textFieldBG)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.subtitle.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Actions

    /// Whether the "Opsi Lain" sheet has anything to show (approve/reject/delete,
    /// all role/status-gated).
    private var hasMoreOptions: Bool {
        presenter.canApproveOrReject || presenter.canDelete
    }

    @ViewBuilder
    private func actionBar(_ detail: CashReceiptDetail) -> some View {
        if presenter.canEdit || hasMoreOptions {
            HStack {
                if presenter.canApproveOrReject {
                    // Approve/reject still live behind the menu alongside delete.
                    pillButton("Opsi Lain", systemImage: "ellipsis.circle") { showMoreOptions = true }
                } else if presenter.canDelete {
                    pillButton("Hapus", systemImage: "trash", tint: .expense) { showDeleteConfirm = true }
                }
                Spacer(minLength: 12)
                if presenter.canEdit {
                    pillButton("Ubah", systemImage: "pencil") { showEdit = true }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    /// An outlined capsule action button (the reference's bottom Edit / More
    /// Options pills), sized to its content so the pair floats to the corners.
    private func pillButton(_ title: String, systemImage: String, tint: Color = .accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 15, weight: .medium))
                Text(title).customFont(.semibold, Typography.body)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .overlay(
                Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .disabled(presenter.isWorking)
    }

    /// Runs an action and reloads the list on success; surfaces the error otherwise.
    private func act(_ op: @escaping () async -> Bool) async {
        if await op() { onChanged() } else { actionError = presenter.actionErrorMessage }
    }

    // MARK: - Helpers

    private func stateMessage(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.subtitle)
            Text(text)
                .customFont(.medium, Typography.body)
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
