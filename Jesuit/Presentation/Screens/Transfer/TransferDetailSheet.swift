//
//  TransferDetailSheet.swift
//  Jesuit
//
//  Transfer Dana detail: amount hero, transfer fields (from → to), the optional
//  FX summary, attachments, the Riwayat tab, and the role/status-gated actions
//  (Ubah / Setujui / Tolak / Hapus). Mirrors CashReceiptDetailSheet minus the
//  journal-line table.
//

import SwiftUI

struct TransferDetailSheet: View {
    let id: String
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var presenter: TransferDetailPresenter
    @State private var showApprove = false
    @State private var showReject = false
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    @State private var showMoreOptions = false
    @State private var previewImage: PreviewImage?
    @State private var tab: DetailTab = .detail
    @State private var rejectReason = ""
    @State private var actionError: String?

    private enum DetailTab: String, CaseIterable, Identifiable {
        case detail = "Detail"
        case riwayat = "Riwayat"
        var id: String { rawValue }
    }

    init(id: String, onChanged: @escaping () -> Void) {
        self.id = id
        self.onChanged = onChanged
        _presenter = State(initialValue: AppDI.shared.transferDetailPresenter(id: id))
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
                CreateTransferSheet(editing: detail, onCreated: {
                    onChanged()
                    Task { await presenter.load() }
                })
            }
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
        .alert("Setujui transfer?", isPresented: $showApprove) {
            Button("Batal", role: .cancel) {}
            Button("Setujui") { Task { await act { await presenter.approve(comment: "") } } }
        } message: {
            Text("Transfer akan diposting ke buku besar.")
        }
        .alert("Tolak transfer", isPresented: $showReject) {
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
        .alert("Hapus transfer?", isPresented: $showDeleteConfirm) {
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

    // MARK: - Content

    private func content(_ detail: FundTransferDetail) -> some View {
        VStack(spacing: 16) {
            hero(detail)

            Picker("", selection: $tab) {
                ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

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

    private func detailPage(_ detail: FundTransferDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                infoCard(detail)
                if detail.isForeign { fxCard(detail) }
                if !detail.attachments.isEmpty { attachmentsCard(detail.attachments) }
                if !detail.description.isEmpty { notesCard(detail.description) }
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

    // MARK: - Hero

    private func hero(_ detail: FundTransferDetail) -> some View {
        VStack(spacing: 8) {
            Text(detail.amount.asCurrency(detail.currencyCode))
                .customFont(.bold, Typography.display)
                .foregroundStyle(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("\(detail.fromAccountName)  →  \(detail.toAccountName)")
                .customFont(.regular, Typography.subhead)
                .foregroundStyle(.subtitle)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            statusPill(detail).padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .padding(.horizontal, 20)
    }

    private func statusPill(_ detail: FundTransferDetail) -> some View {
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

    // MARK: - Info card

    private func infoCard(_ detail: FundTransferDetail) -> some View {
        VStack(spacing: 0) {
            infoRow("No. Transfer", detail.number)
            cardDivider
            infoRow("Tanggal", Self.dayFormat(detail.date))
            cardDivider
            infoRow("Dari Akun", detail.fromAccountName)
            if !detail.fromBranchName.isEmpty {
                cardDivider
                infoRow("Dari Cabang", detail.fromBranchName)
            }
            cardDivider
            infoRow("Ke Akun", detail.toAccountName)
            if !detail.toBranchName.isEmpty {
                cardDivider
                infoRow("Ke Cabang", detail.toBranchName)
            }
            cardDivider
            infoRow("Jurnal Terkait", detail.hasJournal ? "Terbentuk" : "Belum terbentuk")
            cardDivider
            infoRow("Terakhir Diperbarui", Self.dateTimeFormat(detail.updatedAt))
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fxCard(_ detail: FundTransferDetail) -> some View {
        VStack(spacing: 0) {
            infoRow("Kurs", "1 \(detail.foreignCurrency) = \(detail.exchangeRate.asRupiah)")
            cardDivider
            infoRow("Jumlah Asal", "\(detail.foreignCurrency) \(TransferPresenter.CreateForm.foreignString(detail.originalAmount))")
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

    // MARK: - Attachments

    private func attachmentsCard(_ attachments: [CashLineAttachment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lampiran (\(attachments.count))")
                .customFont(.semibold, Typography.body)
                .foregroundStyle(.title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        attachmentChip(attachment)
                    }
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

    // MARK: - Riwayat

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

    // MARK: - Actions

    private var hasMoreOptions: Bool {
        presenter.canApproveOrReject || presenter.canDelete
    }

    @ViewBuilder
    private func actionBar(_ detail: FundTransferDetail) -> some View {
        if presenter.canEdit || hasMoreOptions {
            HStack {
                if presenter.canApproveOrReject {
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

    private func pillButton(_ title: String, systemImage: String, tint: Color = .accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 15, weight: .medium))
                Text(title).customFont(.semibold, Typography.body)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .disabled(presenter.isWorking)
    }

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
