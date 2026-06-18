//
//  PenerimaanPresenter.swift
//  Jesuit
//
//  Presenter for the Penerimaan (cash receipts) tab: loads receipts from the
//  finance API, then applies status filtering, search and per-status counts
//  for the filter tabs.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class PenerimaanPresenter {
    private let repository: CashReceiptRepositoryProtocol

    /// Status filter selection — the four real API statuses plus "All".
    /// `rawValue` is the chip/sheet label; `status` maps to the receipt status
    /// (`nil` == all).
    enum Filter: String, CaseIterable, Identifiable, Sendable {
        case all      = "Semua"
        case draft    = "Draft"
        case waiting  = "Menunggu"
        case posted   = "Disetujui"
        case rejected = "Ditolak"
        var id: String { rawValue }

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
    var sortField: ReceiptSortField = .createdTime
    var sortDirection: SortDirection = .newToOld
    var searchText: String = ""

    private(set) var receipts: [CashReceipt] = []
    private(set) var state: AppState<[CashReceipt]> = .idle

    /// Per-status counts from the API `meta.counts`, used for the tab badges so
    /// they reflect the full result set rather than just the loaded page.
    private(set) var serverCounts: CashTransactionCounts?

    private let pageSize = 25

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

    /// Loads the first page of cash receipts from the finance API.
    func load() async {
        state = .loading
        do {
            let page = try await repository.fetchReceipts(page: 1, limit: pageSize)
            receipts = page.receipts
            serverCounts = page.counts
            state = page.receipts.isEmpty ? .empty : .success(page.receipts)
        } catch {
            receipts = []
            serverCounts = nil
            state = .error(error)
        }
    }

    // MARK: - Derived

    /// Receipts after applying the filter chip, search query and sort.
    var filtered: [CashReceipt] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let status = filter.status
        return receipts
            .filter { status == nil || $0.status == status }
            .filter { query.isEmpty
                || $0.number.lowercased().contains(query)
                || $0.description.lowercased().contains(query) }
            .sorted { CashReceipt.isOrdered($0, $1, by: sortField, sortDirection) }
    }

    /// Total count for a given tab (`nil` == Semua). Prefers the server-provided
    /// counts; falls back to counting the loaded page.
    func count(for status: ReceiptStatus?) -> Int {
        if let counts = serverCounts {
            switch status {
            case .none:             return counts.all ?? receipts.count
            case .draft:            return counts.draft ?? 0
            case .pendingApproval:  return counts.waiting ?? 0
            case .approved:         return counts.posted ?? 0
            case .rejected:         return counts.rejected ?? 0
            }
        }
        guard let status else { return receipts.count }
        return receipts.filter { $0.status == status }.count
    }

    // MARK: - Create receipt form

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
        var amountText: String    // Jumlah (digits only)
        var attachments: [CashAttachment]            // newly-picked local files
        var existingAttachments: [CashLineAttachment]  // already uploaded (server)

        init(
            lineId: String? = nil,
            accountId: String? = nil,
            description: String = "",
            amountText: String = "",
            attachments: [CashAttachment] = [],
            existingAttachments: [CashLineAttachment] = []
        ) {
            self.lineId = lineId
            self.accountId = accountId
            self.description = description
            self.amountText = amountText
            self.attachments = attachments
            self.existingAttachments = existingAttachments
        }

        var amount: Double { Double(amountText) ?? 0 }

        var isValid: Bool {
            accountId != nil
                && amount > 0
                && !description.trimmingCharacters(in: .whitespaces).isEmpty
        }

        /// Detached copy for editing; changes only land via `CreateForm.commit`.
        func copy() -> LineDraft {
            LineDraft(lineId: lineId, accountId: accountId, description: description,
                      amountText: amountText, attachments: attachments,
                      existingAttachments: existingAttachments)
        }

        /// Overwrites fields from an edited copy (commit on "Tambah").
        func apply(_ other: LineDraft) {
            accountId = other.accountId
            description = other.description
            amountText = other.amountText
            attachments = other.attachments
            existingAttachments = other.existingAttachments
        }
    }

    /// Drives the create-receipt sheet: the header (date + cash account), the
    /// editable lines, picker options and the save lifecycle. Mirrors the web
    /// "Penerimaan Kas Baru" dialog.
    @Observable
    @MainActor
    final class CreateForm {
        var date: Date = .now
        var cashAccountId: String?          // Akun Kas/Bank (header)
        var lines: [LineDraft] = []

        /// Non-nil when editing an existing transaction (PUT instead of create).
        private(set) var editId: String?

        private(set) var accounts: [AccountDTO] = []
        private var defaultBranchId: String?
        private(set) var saveState: AppState<CashReceipt> = .idle

        var isEditing: Bool { editId != nil }

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
    /// preselecting the first cash account (kept when editing).
    func loadFormOptions() async {
        async let accountsResult = try? repository.fetchCashAccounts()
        async let branchesResult = try? repository.fetchBranches()
        let accounts = await accountsResult ?? []
        let branches = await branchesResult ?? []

        form.setOptions(accounts: accounts, branches: branches)
    }

    /// Saves the form. When editing, PUTs the update; otherwise creates as draft
    /// or submitted. On success resets the form, reloads the list and returns
    /// `true` so the caller can dismiss.
    func save(submit: Bool) async -> Bool {
        guard form.canSave, let cashAccountId = form.cashAccountId,
              let branchId = form.branchId else { return false }

        form.beginSave()
        let request = CashTransactionRequest(
            type: "receipt",
            branchId: branchId,
            cashAccountId: cashAccountId,
            date: form.date,
            lines: form.lines.map {
                .init(
                    accountId: $0.accountId ?? cashAccountId,
                    description: $0.description.trimmingCharacters(in: .whitespaces),
                    amount: $0.amount
                )
            }
        )
        let attachments = form.lines.flatMap(\.attachments)
        do {
            let saved: CashReceipt
            if let editId = form.editId {
                saved = try await repository.update(id: editId, request: request)
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
}

extension PenerimaanPresenter.CreateForm {
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
        lines = detail.lines.map { line in
            PenerimaanPresenter.LineDraft(
                lineId: line.id,
                accountId: line.accountId,
                description: line.description,
                amountText: String(Int(line.amount)),
                existingAttachments: line.attachments
            )
        }
    }

    /// A new detached line for the "Tambah Baris" sheet, prefilled with the
    /// header cash account. Not added to `lines` until `commit` is called.
    func newLine() -> PenerimaanPresenter.LineDraft {
        PenerimaanPresenter.LineDraft(accountId: cashAccountId)
    }

    /// Commits an edited draft (called only on "Tambah").
    func commit(_ draft: PenerimaanPresenter.LineDraft,
                replacing original: PenerimaanPresenter.LineDraft?) {
        if let original, lines.contains(where: { $0.id == original.id }) {
            original.apply(draft)
        } else {
            lines.append(draft)
        }
    }

    func removeLine(_ line: PenerimaanPresenter.LineDraft) {
        lines.removeAll { $0.id == line.id }
    }

    func beginSave() { saveState = .loading }
    func finishSave(_ receipt: CashReceipt) { saveState = .success(receipt) }
    func failSave(_ error: Error) { saveState = .error(error) }
}
