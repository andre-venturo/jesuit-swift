//
//  PengeluaranPresenter.swift
//  Jesuit
//
//  Presenter for the Pengeluaran (expenses) tab: loads cash disbursements from
//  the finance API, then applies status filtering, search and per-status counts
//  for the filter tabs.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class PengeluaranPresenter {
    private let repository: CashReceiptRepositoryProtocol

    /// Status filter selection — the four real API statuses plus "All".
    enum Filter: String, CaseIterable, Identifiable, Sendable {
        case all      = "Semua"
        case draft    = "Draft"
        case waiting  = "Menunggu"
        case posted   = "Disetujui"
        case rejected = "Ditolak"
        var id: String { rawValue }

        /// Subset shown as inline quick chips (the full list lives in the Filter
        /// sheet). Keeps the chip row from overflowing.
        static let quickChips: [Filter] = [.all, .draft, .waiting]

        /// Status this filter matches; `nil` for `.all`.
        var status: ReceiptStatus? {
            switch self {
            case .all:      return nil
            case .draft:    return .draft
            case .waiting:  return .pendingApproval
            case .posted:   return .approved
            case .rejected: return .rejected
            }
        }
    }

    var filter: Filter = .all
    var searchText: String = ""

    private(set) var expenses: [CashReceipt] = []
    private(set) var state: AppState<[CashReceipt]> = .idle

    /// Set after an edit save when some line attachments failed to upload — the
    /// transaction itself saved, so the caller dismisses but warns the user.
    var attachmentWarning: String?

    /// True when the last `loadMore()` page fetch failed, so the list can offer a retry.
    private(set) var loadMoreFailed = false

    /// Per-status counts from the API `meta.counts`, used for the tab badges so
    /// they reflect the full result set rather than just the loaded page.
    private(set) var serverCounts: CashTransactionCounts?

    private let pageSize = 10
    private var page = 1
    private var totalPages = 1

    init(repository: CashReceiptRepositoryProtocol) {
        self.repository = repository
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = state {
            return LoginPresenter.message(for: error)
        }
        return nil
    }

    var isLoadingMore: Bool {
        if case .loadmore = state { return true }
        return false
    }

    /// More server pages remain (load-more only pages the unfiltered list).
    var canLoadMore: Bool { page < totalPages }

    /// Loads the first page of cash disbursements from the finance API.
    func load() async {
        state = .loading
        do {
            let result = try await repository.fetchDisbursements(page: 1, limit: pageSize)
            expenses = result.receipts
            serverCounts = result.counts
            page = 1
            totalPages = result.totalPages
            state = result.receipts.isEmpty ? .empty : .success(result.receipts)
        } catch {
            expenses = []
            serverCounts = nil
            state = .error(error)
        }
    }

    /// Appends the next page; no-op while already paging or at the last page.
    func loadMore() async {
        guard canLoadMore, case .success = state else { return }
        state = .loadmore
        loadMoreFailed = false
        do {
            let result = try await repository.fetchDisbursements(page: page + 1, limit: pageSize)
            page += 1
            totalPages = result.totalPages
            let seen = Set(expenses.map(\.id))
            expenses += result.receipts.filter { !seen.contains($0.id) }
        } catch {
            // Keep what we have, but tell the user the next page failed so they can retry.
            loadMoreFailed = true
        }
        state = .success(expenses)
    }

    // MARK: - Derived

    /// Expenses after applying the filter chip and search query. Order is kept as
    /// the API returns it (the endpoint has no sort param).
    var filtered: [CashReceipt] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let status = filter.status
        return expenses
            .filter { status == nil || $0.status == status }
            .filter { query.isEmpty
                || $0.number.lowercased().contains(query)
                || $0.description.lowercased().contains(query) }
    }

    /// Total count for a given tab (`nil` == Semua). Prefers the server-provided
    /// counts; falls back to counting the loaded page.
    func count(for status: ReceiptStatus?) -> Int {
        if let counts = serverCounts {
            switch status {
            case .none:             return counts.all ?? expenses.count
            case .draft:            return counts.draft ?? 0
            case .pendingApproval:  return counts.waiting ?? 0
            case .approved:         return counts.posted ?? 0
            case .rejected:         return counts.rejected ?? 0
            }
        }
        guard let status else { return expenses.count }
        return expenses.filter { $0.status == status }.count
    }

    var total: Double { expenses.reduce(0) { $0 + $1.amount } }

    // MARK: - Create expense form

    /// One editable "Detail Baris" row in the create sheet.
    @Observable
    @MainActor
    final class LineDraft: Identifiable {
        let id = UUID()
        /// Server line id when editing an existing transaction (nil for new lines);
        /// needed to upload edit-time attachments to the right line.
        var lineId: String?
        var accountId: String?   // Akun Lawan
        var description: String   // Deskripsi
        var amountText: String    // Jumlah IDR (digits only) — the stored amount
        /// Transient foreign-currency amount (e.g. USD) for the dual-field editor;
        /// not persisted — `amountText` (Rp) is the source of truth.
        var foreignAmountText: String
        var attachments: [CashAttachment]            // newly-picked local files
        var existingAttachments: [CashLineAttachment]  // already uploaded (server)

        init(
            lineId: String? = nil,
            accountId: String? = nil,
            description: String = "",
            amountText: String = "",
            foreignAmountText: String = "",
            attachments: [CashAttachment] = [],
            existingAttachments: [CashLineAttachment] = []
        ) {
            self.lineId = lineId
            self.accountId = accountId
            self.description = description
            self.amountText = amountText
            self.foreignAmountText = foreignAmountText
            self.attachments = attachments
            self.existingAttachments = existingAttachments
        }

        var amount: Double { Double(amountText) ?? 0 }

        /// Description is optional (the editor doesn't mark it required and the
        /// API accepts empty), so a line is valid with an account and amount.
        var isValid: Bool {
            accountId != nil && amount > 0
        }

        /// Detached copy for editing; changes only land via `CreateForm.commit`.
        func copy() -> LineDraft {
            LineDraft(lineId: lineId, accountId: accountId, description: description,
                      amountText: amountText, foreignAmountText: foreignAmountText,
                      attachments: attachments, existingAttachments: existingAttachments)
        }

        /// Overwrites fields from an edited copy (commit on "Tambah").
        func apply(_ other: LineDraft) {
            accountId = other.accountId
            description = other.description
            amountText = other.amountText
            foreignAmountText = other.foreignAmountText
            attachments = other.attachments
            existingAttachments = other.existingAttachments
        }
    }

    /// Drives the create-expense sheet: the header (date + cash account), the
    /// editable lines, picker options and the save lifecycle. Mirrors the web
    /// "Pengeluaran Kas Baru" dialog.
    @Observable
    @MainActor
    final class CreateForm {
        var date: Date = .now
        var cashAccountId: String?          // Akun Kas/Bank (header)
        var lines: [LineDraft] = []
        /// `base`→IDR rate for a foreign-currency cash account (1 for IDR).
        var exchangeRate: Double = 1

        /// Non-nil when editing an existing transaction (PUT instead of create).
        private(set) var editId: String?

        private(set) var accounts: [AccountDTO] = []
        private var defaultBranchId: String?
        private(set) var saveState: AppState<CashReceipt> = .idle

        var isEditing: Bool { editId != nil }

        /// Currency of the selected cash account; drives the Kurs row + dual line
        /// fields. Line amounts are always stored in IDR.
        var selectedCurrencyCode: String {
            accounts.first { $0.id == cashAccountId }?.currencyCode ?? "IDR"
        }
        var isForeign: Bool { selectedCurrencyCode.uppercased() != "IDR" }

        var total: Double { lines.reduce(0) { $0 + $1.amount } }

        var isSaving: Bool {
            if case .loading = saveState { return true }
            return false
        }

        var errorMessage: String? {
            if case .error(let error) = saveState {
                return LoginPresenter.message(for: error)
            }
            return nil
        }

        var canSave: Bool {
            cashAccountId != nil
                && !lines.isEmpty
                && lines.allSatisfy(\.isValid)
                && !isSaving
        }

        var cashAccountName: String {
            accountName(for: cashAccountId) ?? "Pilih akun"
        }

        func accountName(for id: String?) -> String? {
            accounts.first { $0.id == id }.map { acc in
                acc.code.map { "\($0) — \(acc.name)" } ?? acc.name
            }
        }

        var branchId: String? { defaultBranchId }
    }

    var form = CreateForm()

    /// Resets the form for a brand-new transaction (clears any prior edit).
    func startCreate() {
        form = CreateForm()
    }

    /// Seeds the form from an existing transaction for editing (PUT on save).
    func startEditing(_ detail: CashReceiptDetail) {
        let f = CreateForm()
        f.seed(from: detail)
        form = f
    }

    /// Loads the cash-account picker (and default branch) for the create sheet,
    /// preselecting the first cash account and seeding one empty line.
    func loadFormOptions() async {
        async let accountsResult = try? repository.fetchCashAccounts()
        async let branchesResult = try? repository.fetchBranches()
        let accounts = await accountsResult ?? []
        let branches = await branchesResult ?? []

        form.setOptions(accounts: accounts, branches: branches)
    }

    /// Reacts to a cash-account change: for a foreign-currency account, fetches a
    /// fresh `currency`→IDR rate to prefill Kurs; resets to 1 for IDR. Failure is
    /// non-fatal — the prior rate is kept (the user can still type one).
    func onCashAccountChanged() async {
        guard form.isForeign else { form.exchangeRate = 1; return }
        if let rate = try? await repository.fetchExchangeRate(base: form.selectedCurrencyCode),
           rate > 0 {
            form.exchangeRate = rate
        }
    }

    /// Saves the create form, either as a draft or submitted. On success resets
    /// the form, reloads the list and returns `true` so the caller can dismiss.
    func save(submit: Bool) async -> Bool {
        guard form.canSave, let cashAccountId = form.cashAccountId,
              let branchId = form.branchId else { return false }

        form.beginSave()
        let request = CashTransactionRequest(
            type: "disbursement",
            branchId: branchId,
            cashAccountId: cashAccountId,
            date: form.date,
            lines: form.lines.map {
                .init(
                    lineId: $0.lineId,
                    accountId: $0.accountId ?? cashAccountId,
                    description: $0.description.trimmingCharacters(in: .whitespaces),
                    amount: $0.amount
                )
            },
            currencyCode: form.selectedCurrencyCode,
            exchangeRate: form.exchangeRate
        )
        let attachments = form.lines.flatMap(\.attachments)
        attachmentWarning = nil
        do {
            let saved: CashReceipt
            if let editId = form.editId {
                let detail = try await repository.update(id: editId, request: request)
                let failed = await uploadEditAttachments(transactionId: editId, serverLines: detail.lines ?? [])
                if failed > 0 {
                    attachmentWarning = "Transaksi tersimpan, tetapi \(failed) lampiran gagal diunggah. Buka kembali untuk mencoba lagi."
                }
                saved = CashReceipt(detail: detail)
            } else {
                saved = submit
                    ? try await repository.submit(request, attachments: attachments)
                    : try await repository.saveDraft(request, attachments: attachments)
            }
            form.finishSave(saved)
            form = CreateForm()
            await load()
            return true
        } catch {
            form.failSave(error)
            return false
        }
    }

    /// Uploads each line's newly-picked local attachments after an update PUT.
    /// The web client does this as separate `POST .../lines/{lineId}/attachments`
    /// calls; the JSON PUT alone never carries files. Server line ids come back in
    /// request order, so new lines (no prior `lineId`) match by index.
    /// Returns the number of attachments that failed to upload.
    private func uploadEditAttachments(
        transactionId: String,
        serverLines: [CashTransactionLineDTO]
    ) async -> Int {
        var failed = 0
        for (index, line) in form.lines.enumerated() where !line.attachments.isEmpty {
            let mappedId = serverLines.indices.contains(index) ? serverLines[index].id : nil
            guard let lineId = line.lineId ?? mappedId else { failed += line.attachments.count; continue }
            for attachment in line.attachments {
                do {
                    _ = try await repository.uploadLineAttachment(
                        transactionId: transactionId,
                        lineId: lineId,
                        attachment: attachment
                    )
                } catch {
                    failed += 1
                }
            }
        }
        return failed
    }
}

extension PengeluaranPresenter.CreateForm {
    func setOptions(accounts: [AccountDTO], branches: [BranchDTO]) {
        self.accounts = accounts
        self.defaultBranchId = (branches.first { $0.isDefault == true } ?? branches.first)?.id
        if cashAccountId == nil { cashAccountId = accounts.first?.id }
    }

    /// Seeds the form from an existing transaction's detail for editing.
    func seed(from detail: CashReceiptDetail) {
        editId = detail.id
        date = detail.date
        cashAccountId = detail.cashAccountId
        // Keep the transaction's stored rate so editing doesn't re-fetch/override.
        exchangeRate = detail.exchangeRate > 0 ? detail.exchangeRate : 1
        let rate = exchangeRate
        let foreign = detail.currencyCode.uppercased() != "IDR"
        lines = detail.lines.map { line in
            PengeluaranPresenter.LineDraft(
                lineId: line.id,
                accountId: line.accountId,
                description: line.description,
                amountText: String(Int(line.amount)),
                // Back-compute the foreign field from the stored Rp amount.
                foreignAmountText: (foreign && rate > 0)
                    ? Self.foreignString(line.amount / rate) : "",
                existingAttachments: line.attachments
            )
        }
    }

    /// Formats a computed foreign amount for the editor field: drops the decimal
    /// when whole (e.g. `10`), else 2 dp with a dot separator (e.g. `10.5`).
    static func foreignString(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value.rounded())) }
        return String(format: "%.2f", value)
    }

    /// A new detached line for the "Tambah Baris" sheet, prefilled with the
    /// header cash account. Not added to `lines` until `commit` is called.
    func newLine() -> PengeluaranPresenter.LineDraft {
        PengeluaranPresenter.LineDraft(accountId: cashAccountId)
    }

    /// Commits an edited draft (called only on "Tambah"). When `replacing` is a
    /// row already in `lines`, its fields are overwritten; otherwise the draft is
    /// appended as a new row.
    func commit(_ draft: PengeluaranPresenter.LineDraft,
                replacing original: PengeluaranPresenter.LineDraft?) {
        if let original, lines.contains(where: { $0.id == original.id }) {
            original.apply(draft)
        } else {
            lines.append(draft)
        }
    }

    func removeLine(_ line: PengeluaranPresenter.LineDraft) {
        lines.removeAll { $0.id == line.id }
    }

    func beginSave() { saveState = .loading }
    func finishSave(_ receipt: CashReceipt) { saveState = .success(receipt) }
    func failSave(_ error: Error) { saveState = .error(error) }
}
